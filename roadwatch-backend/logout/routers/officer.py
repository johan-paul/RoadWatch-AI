import uuid
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.models import (
    User, Complaint, RepairLog, AuditLog,
    ComplaintStatus, RepairStatus
)
from app.schemas.schemas import RepairLogOut, RepairLogCreate, RepairLogUpdate, UserOut
from app.middleware.auth import require_officer
from app.services.storage_service import upload_image, validate_image
from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/officer", tags=["officer"])


# ── GET /officer/profile ──────────────────────────────────────────────────────

@router.get("/profile", response_model=UserOut)
async def get_profile(current_user: User = Depends(require_officer)):
    return current_user


# ── GET /officer/stats ────────────────────────────────────────────────────────

@router.get("/stats")
async def get_officer_stats(
    current_user: User = Depends(require_officer),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import func
    base = select(func.count()).select_from(Complaint).where(
        Complaint.assigned_officer_id == current_user.id
    )

    total = (await db.execute(base)).scalar()
    pending = (await db.execute(
        base.where(Complaint.status == ComplaintStatus.assigned)
    )).scalar()
    in_progress = (await db.execute(
        base.where(Complaint.status == ComplaintStatus.in_progress)
    )).scalar()
    resolved = (await db.execute(
        base.where(Complaint.status == ComplaintStatus.resolved)
    )).scalar()

    return {
        "total_assigned": total,
        "pending": pending,
        "in_progress": in_progress,
        "resolved": resolved,
    }


# ── POST /officer/complaints/{id}/start ──────────────────────────────────────

@router.post("/complaints/{complaint_id}/start", response_model=dict)
async def start_repair(
    complaint_id: uuid.UUID,
    current_user: User = Depends(require_officer),
    db: AsyncSession = Depends(get_db),
):
    """Officer marks complaint as in-progress and optionally uploads before image."""
    result = await db.execute(select(Complaint).where(Complaint.id == complaint_id))
    complaint = result.scalar_one_or_none()

    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found.")
    if complaint.assigned_officer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not assigned to you.")
    if complaint.status not in (ComplaintStatus.assigned, ComplaintStatus.pending):
        raise HTTPException(status_code=400, detail=f"Cannot start repair from status '{complaint.status}'.")

    complaint.status = ComplaintStatus.in_progress

    # Create repair log
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

    return {"message": "Repair started.", "complaint_id": str(complaint.id)}


# ── POST /officer/complaints/{id}/before-image ───────────────────────────────

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
        settings.STORAGE_BUCKET_REPAIRS
    )
    repair_log.before_image_url = result["url"]
    return {"url": result["url"]}


# ── POST /officer/complaints/{id}/complete ────────────────────────────────────

@router.post("/complaints/{complaint_id}/complete")
async def complete_repair(
    complaint_id: uuid.UUID,
    notes: Optional[str] = Form(None),
    after_image: UploadFile = File(...),
    current_user: User = Depends(require_officer),
    db: AsyncSession = Depends(get_db),
):
    """
    Officer submits after-image to mark repair as complete.
    AI comparison score will be computed by a background job.
    """
    complaint = await _get_officer_complaint(complaint_id, current_user, db)

    if complaint.status != ComplaintStatus.in_progress:
        raise HTTPException(status_code=400, detail="Complaint must be in-progress to complete.")

    file_bytes = await after_image.read()
    validate_image(file_bytes)
    result = await upload_image(
        file_bytes, after_image.filename or "after.jpg",
        settings.STORAGE_BUCKET_REPAIRS
    )

    repair_log = await _get_or_create_repair_log(complaint, current_user, db)
    repair_log.after_image_url = result["url"]
    repair_log.status = RepairStatus.completed
    repair_log.notes = notes
    repair_log.completed_at = datetime.now(timezone.utc)

    complaint.status = ComplaintStatus.resolved
    if notes:
        complaint.resolution_notes = notes

    db.add(AuditLog(
        actor_id=current_user.id,
        action="repair_completed",
        target_type="complaint",
        target_id=str(complaint.id),
        metadata={"after_image_url": result["url"]},
    ))

    return {"message": "Repair marked as complete.", "after_image_url": result["url"]}


# ── GET /officer/complaints/{id}/repair-log ───────────────────────────────────

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
