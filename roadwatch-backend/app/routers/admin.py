import uuid
import math
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional, List

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.models import (
    User, Officer, Complaint, AuditLog,
    UserRole, ComplaintStatus, SeverityLevel
)
from app.schemas.schemas import (
    OfficerCreate, OfficerOut, OfficerUpdate,
    UserOut, AdminStatsOut, SuspendRequest,
    ComplaintOut, ComplaintReassign,
    AdminLoginRequest, TokenResponse,
)
from app.middleware.auth import require_admin
from app.services.assignment_service import assign_complaint
from app.services import notification_service as notify
from app.services.jwt_service import (
    create_access_token, create_refresh_token, revoke_all_tokens
)
from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["admin"])


# ── Admin Web Login (no Firebase — password-based for dashboard) ──────────────

@router.post("/auth/login", response_model=TokenResponse)
async def admin_web_login(
    body: AdminLoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Web dashboard login. Accepts admin phone + admin secret from .env.
    No Firebase required — the dashboard runs in a browser, not the phone app.
    """
    if body.admin_secret != settings.ADMIN_SECRET:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials.")

    result = await db.execute(
        select(User).where(
            User.phone_number == body.phone_number,
            User.role == UserRole.admin,
        )
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials.")

    access_token  = create_access_token(str(user.id), user.role.value, user.name)
    refresh_token = await create_refresh_token(str(user.id), db)

    db.add(AuditLog(
        actor_id=user.id,
        action="admin_web_login",
        target_type="user",
        target_id=str(user.id),
        ip_address=_client_ip(request),
    ))

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        role=user.role,
        user_id=str(user.id),
        name=user.name,
    )


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
        ward_number=body.ward_number,
        area_name=body.area_name,
        zone=body.zone,
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
        extra_data={"phone": body.phone_number, "name": body.name},
    ))

    # Eager-load the user relationship before returning (avoids MissingGreenlet)
    refreshed = await db.execute(
        select(Officer)
        .options(selectinload(Officer.user))
        .where(Officer.id == officer.id)
    )
    return refreshed.scalar_one()


@router.get("/officers", response_model=List[OfficerOut])
async def list_officers(
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Officer).options(selectinload(Officer.user))
    )
    return result.scalars().all()


@router.get("/officers/{officer_id}", response_model=OfficerOut)
async def get_officer(
    officer_id: uuid.UUID,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Officer)
        .options(selectinload(Officer.user))
        .where(Officer.id == officer_id)
    )
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
    result = await db.execute(
        select(Officer)
        .options(selectinload(Officer.user))
        .where(Officer.id == officer_id)
    )
    officer = result.scalar_one_or_none()
    if not officer:
        raise HTTPException(status_code=404, detail="Officer not found.")

    user = officer.user  # already loaded via selectinload

    if body.name is not None:
        user.name = body.name
    if body.employee_id is not None:
        officer.employee_id = body.employee_id
    if body.department is not None:
        officer.department = body.department
    if body.ward_number is not None:
        officer.ward_number = body.ward_number
    if body.area_name is not None:
        officer.area_name = body.area_name
    if body.zone is not None:
        officer.zone = body.zone
    if body.jurisdiction_geojson is not None:
        officer.jurisdiction_geojson = body.jurisdiction_geojson

    db.add(AuditLog(
        actor_id=current_user.id,
        action="officer_updated",
        target_type="user",
        target_id=str(user.id),
        ip_address=_client_ip(request),
    ))
    # Re-fetch with eager load so the returned object has user populated
    await db.flush()
    refreshed = await db.execute(
        select(Officer)
        .options(selectinload(Officer.user))
        .where(Officer.id == officer_id)
    )
    return refreshed.scalar_one()


@router.delete("/officers/{officer_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_officer(
    officer_id: uuid.UUID,
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

    await revoke_all_tokens(str(user.id), db)
    await db.delete(officer)
    await db.delete(user)

    db.add(AuditLog(
        actor_id=current_user.id,
        action="officer_deleted",
        target_type="user",
        target_id=str(user.id),
        ip_address=_client_ip(request),
    ))


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

    await revoke_all_tokens(str(user.id), db)

    db.add(AuditLog(
        actor_id=current_user.id,
        action="user_suspended",
        target_type="user",
        target_id=str(user.id),
        ip_address=_client_ip(request),
        extra_data={"reason": body.reason},
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

    try:
        success = await assign_complaint(
            complaint=complaint,
            db=db,
            admin_id=str(current_user.id),
            force_officer_id=str(body.officer_id),
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not success:
        raise HTTPException(status_code=400, detail="Reassignment failed.")

    db.add(AuditLog(
        actor_id=current_user.id,
        action="complaint_reassigned",
        target_type="complaint",
        target_id=str(complaint.id),
        ip_address=_client_ip(request),
        extra_data={"to_officer_id": str(body.officer_id), "reason": body.reason},
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

    total_complaints    = await _count(Complaint)
    pending_complaints  = await _count(Complaint, Complaint.status == ComplaintStatus.pending)
    resolved_complaints = await _count(Complaint, Complaint.status == ComplaintStatus.resolved)
    total_citizens      = await _count(User, User.role == UserRole.citizen)
    total_officers      = await _count(User, User.role == UserRole.officer)
    high_severity_open  = await _count(
        Complaint,
        Complaint.severity == SeverityLevel.high,
        Complaint.status.in_([
            ComplaintStatus.pending,
            ComplaintStatus.assigned,
            ComplaintStatus.in_progress,
        ]),
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


# ── Emergency Escalation ─────────────────────────────────────────────────────

@router.post("/complaints/{complaint_id}/escalate")
async def escalate_complaint(
    complaint_id: uuid.UUID,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Mark a complaint as emergency-escalated and send an FCM alert to the
    assigned officer. Can be called on any non-resolved complaint.
    """
    result = await db.execute(select(Complaint).where(Complaint.id == complaint_id))
    complaint = result.scalar_one_or_none()
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found.")
    if complaint.status in (ComplaintStatus.resolved, ComplaintStatus.rejected,
                            ComplaintStatus.duplicate):
        raise HTTPException(status_code=400,
                            detail="Cannot escalate a resolved/rejected complaint.")

    # Force severity to high
    complaint.severity = SeverityLevel.high

    db.add(AuditLog(
        actor_id=current_user.id,
        action="complaint_escalated",
        target_type="complaint",
        target_id=str(complaint.id),
        extra_data={
            "escalated_by": str(current_user.id),
            "damage_type":  complaint.damage_type.value if complaint.damage_type else None,
        },
    ))

    # Notify the assigned officer (background)
    if complaint.assigned_officer_id:
        officer_res = await db.execute(
            select(User).where(User.id == complaint.assigned_officer_id)
        )
        officer = officer_res.scalar_one_or_none()
        if officer:
            background_tasks.add_task(
                notify.notify_emergency_escalation,
                officer.fcm_token,
                str(complaint.id),
                complaint.damage_type.value if complaint.damage_type else None,
                complaint.location_address,
            )

    return {
        "message":      "Complaint escalated. Officer notified.",
        "complaint_id": str(complaint.id),
        "severity":     "high",
    }


# ── Budget Dashboard ─────────────────────────────────────────────────────────

# Estimated repair cost (INR) per damage type × severity
REPAIR_COST = {
    ("pothole",      "high"):   150_000,
    ("pothole",      "medium"):  75_000,
    ("pothole",      "low"):     30_000,
    ("crack",        "high"):    60_000,
    ("crack",        "medium"):  25_000,
    ("crack",        "low"):     10_000,
    ("waterlogging", "high"):   120_000,
    ("waterlogging", "medium"):  50_000,
    ("waterlogging", "low"):     20_000,
    ("damaged_road", "high"):   200_000,
    ("damaged_road", "medium"):  90_000,
    ("damaged_road", "low"):     40_000,
    ("other",        "high"):    50_000,
    ("other",        "medium"):  20_000,
    ("other",        "low"):     10_000,
}

def _estimate_cost(damage_type: str | None, severity: str | None) -> int:
    dt  = damage_type or "other"
    sev = severity    or "medium"
    return REPAIR_COST.get((dt, sev), 20_000)


@router.get("/budget")
async def get_budget_dashboard(
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns estimated repair budget breakdown based on complaint data.
    No separate budget model needed — costs are computed from complaint × damage type × severity.
    """
    from sqlalchemy import case, and_

    result = await db.execute(select(Complaint))
    complaints = result.scalars().all()

    total_estimated    = 0
    resolved_cost      = 0
    pending_cost       = 0
    in_progress_cost   = 0

    by_type: dict[str, dict] = {}
    monthly: dict[str, int]  = {}

    for c in complaints:
        if c.status in (ComplaintStatus.rejected, ComplaintStatus.duplicate):
            continue

        cost = _estimate_cost(
            c.damage_type.value if c.damage_type else None,
            c.severity.value    if c.severity    else None,
        )
        total_estimated += cost

        if c.status == ComplaintStatus.resolved:
            resolved_cost += cost
        elif c.status == ComplaintStatus.in_progress:
            in_progress_cost += cost
        else:
            pending_cost += cost

        # By damage type
        dt = c.damage_type.value if c.damage_type else "other"
        if dt not in by_type:
            by_type[dt] = {"count": 0, "cost": 0, "resolved": 0}
        by_type[dt]["count"]   += 1
        by_type[dt]["cost"]    += cost
        if c.status == ComplaintStatus.resolved:
            by_type[dt]["resolved"] += 1

        # Monthly trend (last 6 months)
        month_key = c.created_at.strftime("%b %Y")
        monthly[month_key] = monthly.get(month_key, 0) + cost

    # Last 6 months only
    monthly_trend = [
        {"month": k, "estimated_cost": v}
        for k, v in monthly.items()
    ][-6:]

    return {
        "summary": {
            "total_estimated_inr":   total_estimated,
            "resolved_cost_inr":     resolved_cost,
            "pending_cost_inr":      pending_cost,
            "in_progress_cost_inr":  in_progress_cost,
            "resolution_rate_pct":   round(resolved_cost / total_estimated * 100, 1)
                                     if total_estimated > 0 else 0,
        },
        "by_damage_type": [
            {
                "type":         dt,
                "count":        info["count"],
                "estimated_inr": info["cost"],
                "resolved":     info["resolved"],
            }
            for dt, info in by_type.items()
        ],
        "monthly_trend": monthly_trend,
    }


# ── Priority Queue ────────────────────────────────────────────────────────────

@router.get("/complaints/priority-queue")
async def get_priority_queue(
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Return open complaints ranked by priority score.

    Priority Score = severity_weight × risk_score × density_bonus × recency_factor

    severity_weight : high=3.0  medium=2.0  low=1.0
    risk_score      : ai_risk_score (0–1)
    density_bonus   : 1 + (nearby_count × 0.1), capped at 2.0
    recency_factor  : 1.0 for < 24h, 0.8 for 1–3 days, 0.6 for > 3 days
    """
    result = await db.execute(
        select(Complaint).where(
            Complaint.status.in_([
                ComplaintStatus.pending,
                ComplaintStatus.assigned,
                ComplaintStatus.in_progress,
            ])
        )
    )
    complaints = result.scalars().all()

    SEVERITY_WEIGHT = {"high": 3.0, "medium": 2.0, "low": 1.0}
    now = datetime.now(timezone.utc)

    # Build a flat list of (lat, lng) for density calculation
    coords = [(c.location_lat, c.location_lng) for c in complaints]

    def nearby_count(lat, lng, radius_m=300) -> int:
        count = 0
        for clat, clng in coords:
            dlat = math.radians(clat - lat)
            dlng = math.radians(clng - lng)
            a = (math.sin(dlat/2)**2 +
                 math.cos(math.radians(lat)) * math.cos(math.radians(clat)) *
                 math.sin(dlng/2)**2)
            dist = 6_371_000 * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
            if dist <= radius_m:
                count += 1
        return count - 1  # exclude self

    scored = []
    for c in complaints:
        sev_w    = SEVERITY_WEIGHT.get(c.severity.value if c.severity else "low", 1.0)
        risk     = c.ai_risk_score or 0.3
        density  = min(1 + nearby_count(c.location_lat, c.location_lng) * 0.1, 2.0)
        age_days = (now - c.created_at).total_seconds() / 86400
        recency  = 1.0 if age_days < 1 else (0.8 if age_days < 3 else 0.6)
        score    = sev_w * risk * density * recency

        scored.append({
            "complaint_id":       str(c.id),
            "damage_type":        c.damage_type.value if c.damage_type else None,
            "severity":           c.severity.value if c.severity else None,
            "status":             c.status.value,
            "priority_score":     round(score, 3),
            "ai_risk_score":      c.ai_risk_score,
            "confirmation_count": c.confirmation_count,
            "location_address":   c.location_address,
            "location_lat":       c.location_lat,
            "location_lng":       c.location_lng,
            "created_at":         c.created_at.isoformat(),
            "assigned_officer_id": str(c.assigned_officer_id) if c.assigned_officer_id else None,
        })

    scored.sort(key=lambda x: x["priority_score"], reverse=True)
    return scored[:limit]


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
            "metadata": log.extra_data,
            "ip_address": log.ip_address,
            "created_at": log.created_at.isoformat(),
        }
        for log in logs
    ]
