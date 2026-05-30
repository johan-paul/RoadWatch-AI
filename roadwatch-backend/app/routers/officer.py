import uuid
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status, UploadFile, File, Form, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.database import get_db
from app.models.models import (
    User, Complaint, RepairLog, AuditLog,
    ComplaintStatus, RepairStatus, SeverityLevel
)
from app.schemas.schemas import RepairLogOut, UserOut, ComplaintListOut
from app.middleware.auth import require_officer
from app.services.storage_service import upload_image, validate_image
from app.services.repair_service import verify_repair_from_urls
from app.services import notification_service as notify
from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/officer", tags=["officer"])


@router.get("/profile", response_model=UserOut)
async def get_profile(current_user: User = Depends(require_officer)):
    return current_user


@router.get("/stats")
async def get_officer_stats(
    current_user: User = Depends(require_officer),
    db: AsyncSession = Depends(get_db),
):
    """
    Stats for the officer dashboard + profile.
    Field names MUST match the Flutter OfficerStats model:
      total_assigned, in_progress, resolved_this_month,
      avg_resolution_days, pending_high_priority
    """
    async def _count(*conditions):
        q = select(func.count()).select_from(Complaint).where(
            Complaint.assigned_officer_id == current_user.id,
            *conditions,
        )
        return (await db.execute(q)).scalar()

    total_assigned = await _count()
    in_progress    = await _count(Complaint.status == ComplaintStatus.in_progress)
    resolved       = await _count(Complaint.status == ComplaintStatus.resolved)
    pending_high   = await _count(
        Complaint.status == ComplaintStatus.assigned,
        Complaint.severity == SeverityLevel.high,
    )

    # Average resolution time (days) across this officer's resolved complaints
    avg_days_result = await db.execute(
        select(
            func.avg(
                func.extract("epoch", Complaint.updated_at - Complaint.created_at)
            )
        ).where(
            Complaint.assigned_officer_id == current_user.id,
            Complaint.status == ComplaintStatus.resolved,
        )
    )
    avg_epoch = avg_days_result.scalar()
    avg_resolution_days = round((avg_epoch or 0) / 86400, 1)

    return {
        "total_assigned":      total_assigned,
        "in_progress":         in_progress,
        "resolved_this_month": resolved,
        "avg_resolution_days": avg_resolution_days,
        "pending_high_priority": pending_high,
    }


@router.get("/complaints", response_model=ComplaintListOut)
async def list_officer_complaints(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status_filter: Optional[ComplaintStatus] = Query(None, alias="status"),
    current_user: User = Depends(require_officer),
    db: AsyncSession = Depends(get_db),
):
    """List complaints assigned to the current officer (paginated)."""
    query = select(Complaint).where(
        Complaint.assigned_officer_id == current_user.id
    )
    if status_filter:
        query = query.where(Complaint.status == status_filter)

    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar()

    query = query.order_by(Complaint.created_at.desc())
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    items = result.scalars().all()

    return ComplaintListOut(items=items, total=total, page=page, page_size=page_size)


@router.post("/complaints/{complaint_id}/start")
async def start_repair(
    complaint_id: uuid.UUID,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(require_officer),
    db: AsyncSession = Depends(get_db),
):
    complaint = await _get_officer_complaint(complaint_id, current_user, db)

    if complaint.status not in (ComplaintStatus.assigned, ComplaintStatus.pending):
        raise HTTPException(
            status_code=400,
            detail=f"Cannot start repair from status '{complaint.status.value}'.",
        )

    complaint.status = ComplaintStatus.in_progress

    repair_log = RepairLog(
        complaint_id=complaint.id,
        officer_id=current_user.id,
        status=RepairStatus.in_progress,
    )
    db.add(repair_log)
    db.add(AuditLog(
        actor_id=current_user.id,
        action="repair_started",
        target_type="complaint",
        target_id=str(complaint.id),
    ))

    # Notify the citizen (background)
    citizen_result = await db.execute(
        select(User).where(User.id == complaint.citizen_id)
    )
    citizen = citizen_result.scalar_one_or_none()
    if citizen:
        background_tasks.add_task(
            notify.notify_repair_started, citizen.fcm_token, str(complaint.id)
        )

    return {"message": "Repair started.", "complaint_id": str(complaint.id)}


@router.post("/complaints/{complaint_id}/before-image")
async def upload_before_image(
    complaint_id: uuid.UUID,
    image: UploadFile = File(...),
    current_user: User = Depends(require_officer),
    db: AsyncSession = Depends(get_db),
):
    complaint = await _get_officer_complaint(complaint_id, current_user, db)
    repair_log = await _get_or_create_repair_log(complaint, current_user, db)

    file_bytes = await image.read()
    validate_image(file_bytes)
    result = await upload_image(
        file_bytes, image.filename or "before.jpg",
        settings.STORAGE_BUCKET_REPAIRS,
    )
    repair_log.before_image_url = result["url"]
    return {"url": result["url"]}


@router.post("/complaints/{complaint_id}/complete")
async def complete_repair(
    complaint_id: uuid.UUID,
    background_tasks: BackgroundTasks,
    notes: Optional[str] = Form(None),
    after_image: UploadFile = File(...),
    current_user: User = Depends(require_officer),
    db: AsyncSession = Depends(get_db),
):
    """Officer submits after-image to mark repair complete."""
    complaint = await _get_officer_complaint(complaint_id, current_user, db)

    if complaint.status != ComplaintStatus.in_progress:
        raise HTTPException(status_code=400, detail="Complaint must be in-progress to complete.")

    file_bytes = await after_image.read()
    validate_image(file_bytes)
    result = await upload_image(
        file_bytes, after_image.filename or "after.jpg",
        settings.STORAGE_BUCKET_REPAIRS,
    )

    repair_log = await _get_or_create_repair_log(complaint, current_user, db)
    repair_log.after_image_url = result["url"]
    repair_log.notes = notes

    # ── AI Repair Verification ────────────────────────────────────────────────
    before_url = repair_log.before_image_url or complaint.image_url
    verification = await verify_repair_from_urls(
        before_url=before_url,
        after_image_bytes=file_bytes,
    )

    repair_log.ai_verification_score = verification.ai_verification_score
    repair_log.ai_verified           = verification.ai_verified

    if verification.ai_verified:
        repair_log.status         = RepairStatus.completed
        repair_log.completed_at   = datetime.now(timezone.utc)
        complaint.status          = ComplaintStatus.resolved
        # Notify citizen their road is fixed (background)
        cit_res = await db.execute(select(User).where(User.id == complaint.citizen_id))
        cit_usr = cit_res.scalar_one_or_none()
        if cit_usr:
            background_tasks.add_task(
                notify.notify_complaint_resolved, cit_usr.fcm_token, str(complaint.id)
            )
        if notes:
            complaint.resolution_notes = notes
        logger.info(
            f"[repair_ai] Complaint {complaint.id} repair verified "
            f"(score={verification.ai_verification_score:.2f}, "
            f"ssim={verification.ssim:.2f})"
        )
        action_msg = "repair_completed"
        response_msg = "Repair verified and marked as complete."
    else:
        # Keep in_progress, prompt officer to re-submit
        repair_log.status = RepairStatus.in_progress
        logger.warning(
            f"[repair_ai] Complaint {complaint.id} repair NOT verified — "
            f"reason: {verification.reason}"
        )
        action_msg = "repair_verification_failed"
        response_msg = f"Repair not verified: {verification.reason}"

    db.add(AuditLog(
        actor_id=current_user.id,
        action=action_msg,
        target_type="complaint",
        target_id=str(complaint.id),
        extra_data={
            "after_image_url":        result["url"],
            "ai_verified":            verification.ai_verified,
            "ai_verification_score":  verification.ai_verification_score,
            "ssim":                   verification.ssim,
        },
    ))

    return {
        "message":                response_msg,
        "after_image_url":        result["url"],
        "ai_verified":            verification.ai_verified,
        "ai_verification_score":  verification.ai_verification_score,
        "reason":                 verification.reason,
    }


@router.get("/complaints/{complaint_id}/repair-log", response_model=RepairLogOut)
async def get_repair_log(
    complaint_id: uuid.UUID,
    current_user: User = Depends(require_officer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(RepairLog).where(RepairLog.complaint_id == complaint_id)
    )
    log = result.scalar_one_or_none()
    if not log:
        raise HTTPException(status_code=404, detail="Repair log not found.")
    return log


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_officer_complaint(
    complaint_id: uuid.UUID, officer: User, db: AsyncSession
) -> Complaint:
    result = await db.execute(select(Complaint).where(Complaint.id == complaint_id))
    complaint = result.scalar_one_or_none()
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found.")
    if complaint.assigned_officer_id != officer.id:
        raise HTTPException(status_code=403, detail="Not assigned to you.")
    return complaint


async def _get_or_create_repair_log(
    complaint: Complaint, officer: User, db: AsyncSession
) -> RepairLog:
    result = await db.execute(
        select(RepairLog).where(RepairLog.complaint_id == complaint.id)
    )
    log = result.scalar_one_or_none()
    if not log:
        log = RepairLog(
            complaint_id=complaint.id,
            officer_id=officer.id,
            status=RepairStatus.in_progress,
        )
        db.add(log)
        await db.flush()
    return log
