import uuid
import logging
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.database import get_db
from app.models.models import (
    User, Officer, Complaint, AuditLog,
    UserRole, ComplaintStatus, SeverityLevel
)
from app.schemas.schemas import (
    OfficerCreate, OfficerOut, OfficerUpdate,
    UserOut, AdminStatsOut, SuspendRequest,
    ComplaintOut, ComplaintReassign,
)
from app.middleware.auth import require_admin
from app.services.assignment_service import assign_complaint
from app.services.jwt_service import revoke_all_tokens

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["admin"])


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    return forwarded.split(",")[0].strip() if forwarded else request.client.host


# ── Officers ──────────────────────────────────────────────────────────────────

@router.post("/officers", response_model=OfficerOut, status_code=status.HTTP_201_CREATED)
async def create_officer(
    body: OfficerCreate,
    request: Request,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin creates a new officer account. This is the ONLY way to create officers."""
    existing = await db.execute(
        select(User).where(User.phone_number == body.phone_number)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A user with this phone number already exists.",
        )

    user = User(
        phone_number=body.phone_number,
        name=body.name,
        role=UserRole.officer,
        trust_score=100,
        created_by=current_user.id,
    )
    db.add(user)
    await db.flush()

    officer = Officer(
        user_id=user.id,
        employee_id=body.employee_id,
        department=body.department,
        jurisdiction_geojson=body.jurisdiction_geojson,
    )
    db.add(officer)
    await db.flush()

    db.add(AuditLog(
        actor_id=current_user.id,
        action="officer_created",
        target_type="user",
        target_id=str(user.id),
        ip_address=_client_ip(request),
        metadata={"phone": body.phone_number, "name": body.name},
    ))

    return officer


@router.get("/officers", response_model=List[OfficerOut])
async def list_officers(
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Officer).join(User, Officer.user_id == User.id)
    )
    return result.scalars().all()


@router.get("/officers/{officer_id}", response_model=OfficerOut)
async def get_officer(
    officer_id: uuid.UUID,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Officer).where(Officer.id == officer_id))
    officer = result.scalar_one_or_none()
    if not officer:
        raise HTTPException(status_code=404, detail="Officer not found.")
    return officer


@router.patch("/officers/{officer_id}", response_model=OfficerOut)
async def update_officer(
    officer_id: uuid.UUID,
    body: OfficerUpdate,
    request: Request,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Officer).where(Officer.id == officer_id))
    officer = result.scalar_one_or_none()
    if not officer:
        raise HTTPException(status_code=404, detail="Officer not found.")

    user_result = await db.execute(select(User).where(User.id == officer.user_id))
    user = user_result.scalar_one()

    if body.name:
        user.name = body.name
    if body.employee_id is not None:
        officer.employee_id = body.employee_id
    if body.department is not None:
        officer.department = body.department
    if body.jurisdiction_geojson is not None:
        officer.jurisdiction_geojson = body.jurisdiction_geojson

    db.add(AuditLog(
        actor_id=current_user.id,
        action="officer_updated",
        target_type="user",
        target_id=str(user.id),
        ip_address=_client_ip(request),
    ))
    return officer


# ── Suspend / Reinstate ───────────────────────────────────────────────────────

@router.post("/users/{user_id}/suspend", status_code=status.HTTP_200_OK)
async def suspend_user(
    user_id: uuid.UUID,
    body: SuspendRequest,
    request: Request,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    if user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot suspend yourself.")

    user.is_suspended = True
    user.suspension_reason = body.reason

    # Revoke all active tokens immediately
    await revoke_all_tokens(str(user.id), db)

    db.add(AuditLog(
        actor_id=current_user.id,
        action="user_suspended",
        target_type="user",
        target_id=str(user.id),
        ip_address=_client_ip(request),
        metadata={"reason": body.reason},
    ))
    return {"message": f"User {user.name} suspended."}


@router.post("/users/{user_id}/reinstate", status_code=status.HTTP_200_OK)
async def reinstate_user(
    user_id: uuid.UUID,
    request: Request,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    user.is_suspended = False
    user.suspension_reason = None

    db.add(AuditLog(
        actor_id=current_user.id,
        action="user_reinstated",
        target_type="user",
        target_id=str(user.id),
        ip_address=_client_ip(request),
    ))
    return {"message": f"User {user.name} reinstated."}


# ── Complaint Reassignment ────────────────────────────────────────────────────

@router.post("/complaints/{complaint_id}/reassign", response_model=ComplaintOut)
async def reassign_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintReassign,
    request: Request,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Complaint).where(Complaint.id == complaint_id))
    complaint = result.scalar_one_or_none()
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found.")

    if complaint.status == ComplaintStatus.resolved:
        raise HTTPException(status_code=400, detail="Cannot reassign a resolved complaint.")

    success = await assign_complaint(
        complaint=complaint,
        db=db,
        admin_id=str(current_user.id),
        force_officer_id=str(body.officer_id),
    )

    if not success:
        raise HTTPException(status_code=400, detail="Reassignment failed.")

    db.add(AuditLog(
        actor_id=current_user.id,
        action="complaint_reassigned",
        target_type="complaint",
        target_id=str(complaint.id),
        ip_address=_client_ip(request),
        metadata={"to_officer_id": str(body.officer_id), "reason": body.reason},
    ))
    return complaint


# ── Users List ────────────────────────────────────────────────────────────────

@router.get("/users", response_model=List[UserOut])
async def list_users(
    role: Optional[UserRole] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(User)
    if role:
        query = query.where(User.role == role)
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    return result.scalars().all()


# ── Complaints List (admin sees all) ──────────────────────────────────────────

@router.get("/complaints", response_model=List[ComplaintOut])
async def list_all_complaints(
    status_filter: Optional[ComplaintStatus] = Query(None, alias="status"),
    severity_filter: Optional[SeverityLevel] = Query(None, alias="severity"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(Complaint)
    if status_filter:
        query = query.where(Complaint.status == status_filter)
    if severity_filter:
        query = query.where(Complaint.severity == severity_filter)
    query = query.order_by(Complaint.created_at.desc())
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    return result.scalars().all()


# ── Stats Dashboard ───────────────────────────────────────────────────────────

@router.get("/stats", response_model=AdminStatsOut)
async def get_stats(
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    async def _count(model, *conditions):
        q = select(func.count()).select_from(model)
        for c in conditions:
            q = q.where(c)
        return (await db.execute(q)).scalar()

    total_complaints   = await _count(Complaint)
    pending_complaints = await _count(Complaint, Complaint.status == ComplaintStatus.pending)
    resolved_complaints = await _count(Complaint, Complaint.status == ComplaintStatus.resolved)
    total_citizens     = await _count(User, User.role == UserRole.citizen)
    total_officers     = await _count(User, User.role == UserRole.officer)
    high_severity_open = await _count(
        Complaint,
        Complaint.severity == SeverityLevel.high,
        Complaint.status.in_([ComplaintStatus.pending, ComplaintStatus.assigned, ComplaintStatus.in_progress]),
    )

    return AdminStatsOut(
        total_complaints=total_complaints,
        pending_complaints=pending_complaints,
        resolved_complaints=resolved_complaints,
        total_citizens=total_citizens,
        total_officers=total_officers,
        high_severity_open=high_severity_open,
        avg_resolution_hours=None,
    )


# ── Audit Logs ────────────────────────────────────────────────────────────────

@router.get("/audit-logs")
async def get_audit_logs(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    action: Optional[str] = None,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(AuditLog)
    if action:
        query = query.where(AuditLog.action == action)
    query = query.order_by(AuditLog.created_at.desc())
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    logs = result.scalars().all()

    return [
        {
            "id": str(log.id),
            "actor_id": str(log.actor_id) if log.actor_id else None,
            "action": log.action,
            "target_type": log.target_type,
            "target_id": log.target_id,
            "metadata": log.metadata,
            "ip_address": log.ip_address,
            "created_at": log.created_at.isoformat(),
        }
        for log in logs
    ]
