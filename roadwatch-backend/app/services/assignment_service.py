import uuid
import logging
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.models.models import User, Officer, Complaint, ComplaintStatus, UserRole, AuditLog

logger = logging.getLogger(__name__)


def _point_in_polygon(lat: float, lng: float, geojson: dict) -> bool:
    """Ray-casting algorithm — check if (lat, lng) falls inside a GeoJSON polygon."""
    try:
        geo_type = geojson.get("type", "")

        if geo_type == "Polygon":
            coords = geojson["coordinates"][0]
        elif geo_type == "Feature":
            coords = geojson["geometry"]["coordinates"][0]
        elif geo_type == "MultiPolygon":
            for polygon in geojson["coordinates"]:
                if _ray_cast(lat, lng, polygon[0]):
                    return True
            return False
        else:
            return False

        return _ray_cast(lat, lng, coords)
    except Exception:
        return False


def _ray_cast(lat: float, lng: float, coords: list) -> bool:
    inside = False
    j = len(coords) - 1
    for i in range(len(coords)):
        xi, yi = coords[i][0], coords[i][1]   # lng, lat
        xj, yj = coords[j][0], coords[j][1]
        intersect = ((yi > lat) != (yj > lat)) and (
            lng < (xj - xi) * (lat - yi) / (yj - yi + 1e-10) + xi
        )
        if intersect:
            inside = not inside
        j = i
    return inside


async def find_best_officer(
    lat: float,
    lng: float,
    severity: str,
    db: AsyncSession,
) -> Optional[User]:
    """
    Find the most suitable officer for a complaint at (lat, lng).

    3-tier strategy (so a complaint is NEVER left unassigned when officers exist):
      Tier 1 — Jurisdiction polygon contains the point   (most accurate)
      Tier 2 — Officers in the same zone                 (regional fallback)
      Tier 3 — Any active officer                        (guarantee assignment)
    Within each tier, the least-loaded officer wins (load balancing).
    """
    result = await db.execute(
        select(User, Officer)
        .join(Officer, Officer.user_id == User.id)
        .where(User.role == UserRole.officer, User.is_suspended == False)
    )
    rows = result.all()

    if not rows:
        logger.warning("No active officers exist — complaint will remain pending.")
        return None

    # ── Tier 1: Jurisdiction polygon match ────────────────────────────────────
    jurisdiction_matches = [
        (user, officer) for user, officer in rows
        if officer.jurisdiction_geojson
        and _point_in_polygon(lat, lng, officer.jurisdiction_geojson)
    ]
    if jurisdiction_matches:
        jurisdiction_matches.sort(key=lambda x: x[1].workload_count)
        chosen = jurisdiction_matches[0][0]
        logger.info(f"[assign] Tier 1 (jurisdiction) → {chosen.name}")
        return chosen

    # ── Tier 2: Same-zone fallback ────────────────────────────────────────────
    # Resolve the complaint's zone via any officer whose polygon is closest,
    # but since we have no polygon match, we approximate by reusing the zone of
    # the geographically nearest officer (by their area centroid if available).
    # Simpler heuristic: if only one zone exists among officers, use it.
    zones = {officer.zone for _, officer in rows if officer.zone}
    if len(zones) == 1:
        zone_matches = [(u, o) for u, o in rows if o.zone in zones]
        zone_matches.sort(key=lambda x: x[1].workload_count)
        chosen = zone_matches[0][0]
        logger.info(f"[assign] Tier 2 (single-zone fallback) → {chosen.name}")
        return chosen

    # ── Tier 3: Least-loaded active officer (guarantee) ───────────────────────
    rows_sorted = sorted(rows, key=lambda x: x[1].workload_count)
    chosen = rows_sorted[0][0]
    logger.info(
        f"[assign] Tier 3 (least-loaded fallback) → {chosen.name} "
        f"(no jurisdiction matched point {lat:.4f},{lng:.4f})"
    )
    return chosen


async def assign_complaint(
    complaint: Complaint,
    db: AsyncSession,
    admin_id: Optional[str] = None,
    force_officer_id: Optional[str] = None,
) -> bool:
    """
    Assign a complaint to an officer.
    force_officer_id bypasses auto-selection (admin reassignment).
    Returns True if assignment succeeded.
    """
    if force_officer_id:
        officer_result = await db.execute(
            select(User).where(
                User.id == uuid.UUID(force_officer_id),
                User.role == UserRole.officer,
                User.is_suspended == False,
            )
        )
        officer = officer_result.scalar_one_or_none()
        if not officer:
            raise ValueError("Target officer not found or is suspended.")
    else:
        officer = await find_best_officer(
            complaint.location_lat,
            complaint.location_lng,
            complaint.severity.value if complaint.severity else "medium",
            db,
        )

    if not officer:
        return False

    # Decrement previous officer's workload if reassigning
    if complaint.assigned_officer_id and complaint.assigned_officer_id != officer.id:
        await db.execute(
            update(Officer)
            .where(Officer.user_id == complaint.assigned_officer_id)
            .values(workload_count=Officer.workload_count - 1)
        )

    complaint.assigned_officer_id = officer.id
    complaint.status = ComplaintStatus.assigned
    complaint.assigned_at = datetime.now(timezone.utc)

    await db.execute(
        update(Officer)
        .where(Officer.user_id == officer.id)
        .values(workload_count=Officer.workload_count + 1)
    )

    db.add(AuditLog(
        actor_id=uuid.UUID(admin_id) if admin_id else None,
        action="complaint_assigned",
        target_type="complaint",
        target_id=str(complaint.id),
        extra_data={
            "officer_id": str(officer.id),
            "officer_name": officer.name,
            "auto_assigned": force_officer_id is None,
        },
    ))

    logger.info(f"Complaint {complaint.id} → officer {officer.id}")
    return True
