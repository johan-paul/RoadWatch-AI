import uuid
import logging
from datetime import datetime, timezone, date, timedelta
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status, UploadFile, File, Query, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.database import get_db
from app.models.models import (
    User, Complaint, Verification, AuditLog,
    ComplaintStatus, SeverityLevel, DamageType,
    VerificationResponse, UserRole
)
from app.schemas.schemas import (
    ComplaintOut, ComplaintListOut, VerificationCreate,
    VerificationOut, HeatmapResponse, HeatmapPoint,
    ComplaintStatusUpdate, UploadResponse,
)
from app.middleware.auth import get_current_user, require_citizen, require_officer_or_admin
from app.services.storage_service import upload_image, validate_image
from app.services.assignment_service import assign_complaint
from app.services.ai_service import analyze_road_damage, boost_risk_with_density
from app.services.duplicate_service import check_and_mark_duplicate, _haversine_meters
from app.services import notification_service as notify
from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/complaints", tags=["complaints"])

SEVERITY_WEIGHT = {"low": 1.0, "medium": 2.0, "high": 3.0}


# ── POST /complaints  (citizen submits a new complaint) ───────────────────────

@router.post("", response_model=ComplaintOut, status_code=status.HTTP_201_CREATED)
async def create_complaint(
    background_tasks: BackgroundTasks,
    location_lat: float = Form(...),
    location_lng: float = Form(...),
    location_address: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    image: UploadFile = File(...),
    current_user: User = Depends(require_citizen),
    db: AsyncSession = Depends(get_db),
):
    # ── Rate limit ────────────────────────────────────────────────────────────
    today_start = datetime.combine(date.today(), datetime.min.time()).replace(tzinfo=timezone.utc)
    count_result = await db.execute(
        select(func.count()).select_from(Complaint).where(
            Complaint.citizen_id == current_user.id,
            Complaint.created_at >= today_start,
        )
    )
    daily_count = count_result.scalar()
    if daily_count >= settings.MAX_COMPLAINTS_PER_CITIZEN_PER_DAY:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Daily complaint limit ({settings.MAX_COMPLAINTS_PER_CITIZEN_PER_DAY}) reached.",
        )

    # ── Trust score gate ──────────────────────────────────────────────────────
    if current_user.trust_score < settings.MIN_TRUST_SCORE_FOR_ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your trust score is too low to submit complaints. Contact support.",
        )

    # ── Validate & upload image ───────────────────────────────────────────────
    file_bytes = await image.read()
    try:
        validate_image(file_bytes)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    upload_result = await upload_image(
        file_bytes=file_bytes,
        filename=image.filename or "complaint.jpg",
        bucket=settings.STORAGE_BUCKET_COMPLAINTS,
        content_type=image.content_type or "image/jpeg",
    )

    # ── AI Analysis ───────────────────────────────────────────────────────────
    ai_result = analyze_road_damage(file_bytes)

    # ── Complaint density boost ───────────────────────────────────────────────
    if ai_result:
        # Count nearby open complaints for density risk boost
        cutoff = datetime.now(timezone.utc) - timedelta(days=30)
        nearby_res = await db.execute(
            select(Complaint).where(
                Complaint.status.not_in([
                    ComplaintStatus.resolved,
                    ComplaintStatus.rejected,
                    ComplaintStatus.duplicate,
                ]),
                Complaint.created_at >= cutoff,
            )
        )
        nearby_complaints = nearby_res.scalars().all()
        nearby_count = sum(
            1 for c in nearby_complaints
            if _haversine_meters(location_lat, location_lng,
                                  c.location_lat, c.location_lng) <= 300
        )
        if nearby_count > 0:
            ai_result = boost_risk_with_density(ai_result, nearby_count)

    if ai_result:
        # Map AI damage type string → DamageType enum (with fallback)
        try:
            damage_type_enum = DamageType(ai_result.damage_type)
        except ValueError:
            damage_type_enum = DamageType.other

        # Map AI severity string → SeverityLevel enum
        try:
            severity_enum = SeverityLevel(ai_result.severity)
        except ValueError:
            severity_enum = SeverityLevel.medium

        logger.info(
            f"[AI] Complaint from citizen {current_user.id}: "
            f"type={ai_result.damage_type} sev={ai_result.severity} "
            f"conf={ai_result.confidence_score:.2f} risk={ai_result.risk_score:.2f}"
        )
    else:
        # Model not loaded yet — use defaults; complaint still goes through
        damage_type_enum = None
        severity_enum    = SeverityLevel.medium
        logger.info("[AI] Model not loaded — using default severity=medium, damage_type=None")

    # ── Create complaint ──────────────────────────────────────────────────────
    complaint = Complaint(
        citizen_id=current_user.id,
        location_lat=location_lat,
        location_lng=location_lng,
        location_address=location_address,
        description=description,
        image_url=upload_result["url"],
        status=ComplaintStatus.pending,
        damage_type=damage_type_enum,
        severity=severity_enum,
        ai_confidence_score=ai_result.confidence_score if ai_result else None,
        ai_risk_score=ai_result.risk_score       if ai_result else None,
        ai_analysis_raw=ai_result.raw            if ai_result else None,
    )
    db.add(complaint)
    await db.flush()  # Get complaint.id assigned

    # ── Duplicate detection ───────────────────────────────────────────────────
    is_dup = await check_and_mark_duplicate(complaint, db)

    # Extract primitives now (while session is open) for background notifications
    citizen_token = current_user.fcm_token
    cid           = str(complaint.id)
    dmg           = ai_result.damage_type if ai_result else None
    sev           = ai_result.severity    if ai_result else None

    if is_dup:
        logger.info(f"[duplicate] Complaint {complaint.id} marked as duplicate.")
        db.add(AuditLog(
            actor_id=current_user.id,
            action="complaint_duplicate_detected",
            target_type="complaint",
            target_id=cid,
            extra_data={"duplicate_of": str(complaint.duplicate_of)},
        ))
        # Notify citizen about duplicate (background — never blocks response)
        background_tasks.add_task(
            notify.notify_duplicate_detected,
            citizen_token, cid, str(complaint.duplicate_of or ""),
        )
    else:
        # Auto-assign to an officer
        assigned = await assign_complaint(complaint, db)
        db.add(AuditLog(
            actor_id=current_user.id,
            action="complaint_created",
            target_type="complaint",
            target_id=cid,
            extra_data={
                "lat":           location_lat,
                "lng":           location_lng,
                "damage_type":   dmg,
                "severity":      sev or "medium",
                "ai_confidence": ai_result.confidence_score if ai_result else None,
            },
        ))
        # Notify citizen their report was submitted (background)
        background_tasks.add_task(
            notify.notify_complaint_submitted, citizen_token, cid, dmg,
        )
        # Notify the assigned officer (background)
        if assigned and complaint.assigned_officer_id:
            result = await db.execute(
                select(User).where(User.id == complaint.assigned_officer_id)
            )
            officer_user = result.scalar_one_or_none()
            if officer_user:
                background_tasks.add_task(
                    notify.notify_new_assignment,
                    officer_user.fcm_token, cid, dmg, sev,
                )

    # Enrich response with officer info if assigned
    officer_for_response = None
    if complaint.assigned_officer_id:
        ores = await db.execute(
            select(User).where(User.id == complaint.assigned_officer_id)
        )
        officer_for_response = ores.scalar_one_or_none()

    # Flush pending changes (assigned_officer_id, status, assigned_at) BEFORE
    # refreshing. With autoflush=False in our session, refresh would otherwise
    # SELECT the un-updated row, overwrite the in-memory pending values, and
    # silently drop the assignment when the session commits.
    # After flush+refresh, every column (incl. server defaults like updated_at)
    # is hydrated, so Pydantic's sync model_validate can't trigger lazy I/O.
    await db.flush()
    await db.refresh(complaint)
    return ComplaintOut.from_orm_with_officer(complaint, officer_for_response)


# ── GET /complaints  (paginated list) ─────────────────────────────────────────

@router.get("", response_model=ComplaintListOut)
async def list_complaints(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status_filter: Optional[ComplaintStatus] = Query(None, alias="status"),
    severity_filter: Optional[SeverityLevel] = Query(None, alias="severity"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(Complaint)

    if current_user.role == UserRole.citizen:
        query = query.where(Complaint.citizen_id == current_user.id)
    elif current_user.role == UserRole.officer:
        query = query.where(Complaint.assigned_officer_id == current_user.id)

    if status_filter:
        query = query.where(Complaint.status == status_filter)
    if severity_filter:
        query = query.where(Complaint.severity == severity_filter)

    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar()

    query = query.order_by(Complaint.created_at.desc())
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    items = result.scalars().all()

    return ComplaintListOut(items=items, total=total, page=page, page_size=page_size)


# ── GET /complaints/{id} ──────────────────────────────────────────────────────

@router.get("/{complaint_id}", response_model=ComplaintOut)
async def get_complaint(
    complaint_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Complaint).where(Complaint.id == complaint_id))
    complaint = result.scalar_one_or_none()
    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found.")

    if current_user.role == UserRole.citizen and complaint.citizen_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")
    if current_user.role == UserRole.officer and complaint.assigned_officer_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not assigned to you.")

    # Enrich with officer name if assigned
    officer_user = None
    if complaint.assigned_officer_id:
        res = await db.execute(
            select(User).where(User.id == complaint.assigned_officer_id)
        )
        officer_user = res.scalar_one_or_none()

    return ComplaintOut.from_orm_with_officer(complaint, officer_user)


# ── PATCH /complaints/{id}/status  (officer/admin updates status) ─────────────

@router.patch("/{complaint_id}/status", response_model=ComplaintOut)
async def update_status(
    complaint_id: uuid.UUID,
    body: ComplaintStatusUpdate,
    current_user: User = Depends(require_officer_or_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Complaint).where(Complaint.id == complaint_id))
    complaint = result.scalar_one_or_none()
    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found.")

    if current_user.role == UserRole.officer and complaint.assigned_officer_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not assigned to you.")

    old_status = complaint.status
    complaint.status = body.status
    if body.resolution_notes:
        complaint.resolution_notes = body.resolution_notes

    db.add(AuditLog(
        actor_id=current_user.id,
        action="complaint_status_updated",
        target_type="complaint",
        target_id=str(complaint.id),
        extra_data={"from": old_status.value, "to": body.status.value},
    ))
    return complaint


# ── POST /complaints/{id}/verify  (citizen community verification) ────────────

@router.post("/{complaint_id}/verify", response_model=VerificationOut, status_code=status.HTTP_201_CREATED)
async def verify_complaint(
    complaint_id: uuid.UUID,
    body: VerificationCreate,
    evidence: Optional[UploadFile] = File(None),
    current_user: User = Depends(require_citizen),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Complaint).where(Complaint.id == complaint_id))
    complaint = result.scalar_one_or_none()
    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found.")

    if complaint.citizen_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot verify your own complaint.",
        )

    existing = await db.execute(
        select(Verification).where(
            Verification.complaint_id == complaint_id,
            Verification.verifier_id == current_user.id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already verified.")

    evidence_url = None
    if evidence:
        file_bytes = await evidence.read()
        validate_image(file_bytes)
        res = await upload_image(file_bytes, evidence.filename or "evidence.jpg",
                                 settings.STORAGE_BUCKET_COMPLAINTS)
        evidence_url = res["url"]

    verification = Verification(
        complaint_id=complaint_id,
        verifier_id=current_user.id,
        response=body.response,
        evidence_url=evidence_url,
        notes=body.notes,
    )
    db.add(verification)

    if body.response == VerificationResponse.confirmed:
        complaint.confirmation_count += 1
    else:
        complaint.rejection_count += 1

    total_votes = complaint.confirmation_count + complaint.rejection_count
    if total_votes > 0:
        ai_weight    = (complaint.ai_confidence_score or 0.5) * 0.6
        crowd_weight = (complaint.confirmation_count / total_votes) * 0.4
        trust_boost  = min(current_user.trust_score / 100, 1.0) * 0.1
        complaint.verified_confidence_score = min(round(ai_weight + crowd_weight + trust_boost, 3), 1.0)

    return verification


# ── GET /complaints/map/heatmap ───────────────────────────────────────────────

@router.get("/map/heatmap", response_model=HeatmapResponse)
async def get_heatmap(
    min_lat: Optional[float] = Query(None),
    max_lat: Optional[float] = Query(None),
    min_lng: Optional[float] = Query(None),
    max_lng: Optional[float] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(Complaint).where(
        Complaint.status != ComplaintStatus.rejected,
        Complaint.status != ComplaintStatus.duplicate,
    )

    if all(v is not None for v in [min_lat, max_lat, min_lng, max_lng]):
        query = query.where(
            and_(
                Complaint.location_lat >= min_lat,
                Complaint.location_lat <= max_lat,
                Complaint.location_lng >= min_lng,
                Complaint.location_lng <= max_lng,
            )
        )

    result = await db.execute(query)
    complaints = result.scalars().all()

    points = [
        HeatmapPoint(
            lat=c.location_lat,
            lng=c.location_lng,
            weight=SEVERITY_WEIGHT.get(c.severity.value if c.severity else "medium", 1.0),
            complaint_id=str(c.id),
            status=c.status,
        )
        for c in complaints
    ]

    return HeatmapResponse(points=points, total=len(points))
