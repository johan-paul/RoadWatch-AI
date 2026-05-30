import uuid
import logging
from datetime import datetime, timezone, date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Query, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.database import get_db
from app.models.models import (
    User, Complaint, Verification, AuditLog,
    ComplaintStatus, SeverityLevel, VerificationResponse, UserRole
)
from app.schemas.schemas import (
    ComplaintOut, ComplaintListOut, VerificationCreate,
    VerificationOut, HeatmapResponse, HeatmapPoint,
    ComplaintStatusUpdate, UploadResponse,
)
from app.middleware.auth import get_current_user, require_citizen, require_officer_or_admin
from app.services.storage_service import upload_image, validate_image
from app.services.assignment_service import assign_complaint
from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/complaints", tags=["complaints"])

SEVERITY_WEIGHT = {"low": 1.0, "medium": 2.0, "high": 3.0}


# ── POST /complaints  (citizen submits a new complaint) ───────────────────────

@router.post("", response_model=ComplaintOut, status_code=status.HTTP_201_CREATED)
async def create_complaint(
    location_lat: float = Form(...),
    location_lng: float = Form(...),
    location_address: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    image: UploadFile = File(...),
    current_user: User = Depends(require_citizen),
    db: AsyncSession = Depends(get_db),
):
    # ── Rate limit: max N complaints per citizen per day ──
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
            detail=f"Daily complaint limit ({settings.MAX_COMPLAINTS_PER_CITIZEN_PER_DAY}) reached. Try again tomorrow.",
        )

    # ── Trust score gate ──
    if current_user.trust_score < settings.MIN_TRUST_SCORE_FOR_ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your trust score is too low to submit complaints. Contact support.",
        )

    # ── Validate & upload image ──
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

    # ── Create complaint (AI analysis queued separately) ──
    complaint = Complaint(
        citizen_id=current_user.id,
        location_lat=location_lat,
        location_lng=location_lng,
        location_address=location_address,
        description=description,
        image_url=upload_result["url"],
        status=ComplaintStatus.pending,
    )
    db.add(complaint)
    await db.flush()

    # ── Auto-assign officer ──
    # Severity defaults to medium until AI processes it
    complaint.severity = SeverityLevel.medium
    await assign_complaint(complaint, db)

    db.add(AuditLog(
        actor_id=current_user.id,
        action="complaint_created",
        target_type="complaint",
        target_id=str(complaint.id),
        metadata={"lat": location_lat, "lng": location_lng},
    ))

    return complaint


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

    # Citizens see only their own; officers see their assigned; admin sees all
    if current_user.role == UserRole.citizen:
        query = query.where(Complaint.citizen_id == current_user.id)
    elif current_user.role == UserRole.officer:
        query = query.where(Complaint.assigned_officer_id == current_user.id)
    # admin: no filter

    if status_filter:
        query = query.where(Complaint.status == status_filter)
    if severity_filter:
        query = query.where(Complaint.severity == severity_filter)

    # Total count
    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar()

    # Paginate
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

    # Access control
    if current_user.role == UserRole.citizen and complaint.citizen_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")
    if current_user.role == UserRole.officer and complaint.assigned_officer_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not assigned to you.")

    return complaint


# ── PATCH /complaints/{id}/status  (officer updates status) ──────────────────

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
        metadata={"from": old_status.value, "to": body.status.value},
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

    # Cannot verify own complaint
    if complaint.citizen_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot verify your own complaint.",
        )

    # Check duplicate verification
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

    # Update complaint counters and recalculate confidence
    if body.response == VerificationResponse.confirmed:
        complaint.confirmation_count += 1
    else:
        complaint.rejection_count += 1

    total_votes = complaint.confirmation_count + complaint.rejection_count
    if total_votes > 0:
        ai_weight = (complaint.ai_confidence_score or 0.5) * 0.6
        crowd_weight = (complaint.confirmation_count / total_votes) * 0.4
        trust_boost = min(current_user.trust_score / 100, 1.0) * 0.1
        complaint.verified_confidence_score = min(round(ai_weight + crowd_weight + trust_boost, 3), 1.0)

    return verification


# ── GET /complaints/heatmap  ──────────────────────────────────────────────────

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
