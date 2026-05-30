import uuid
import logging
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.models.models import User, Officer, Complaint, ComplaintStatus, UserRole, AuditLog

logger = logging.getLogger(__name__)


def _point_in_polygon(lat: float, lng: float, geojson: dict) -> bool:
    """
    Check if a lat/lng point is inside a GeoJSON polygon.
    Uses ray-casting algorithm.
    """
    try:
        geo_type = geojson.get("type", "")

        if geo_type == "Polygon":
            coords = geojson["coordinates"][0]
        elif geo_type == "Feature":
            coords = geojson["geometry"]["coordinates"][0]
        elif geo_type == "MultiPolygon":
            # Check each polygon
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
    Priority:
      1. Officer whose jurisdiction contains the point
      2. Among matching officers, pick lowest workload
      3. For high severity — ignore workload, pick jurisdiction match only
    """
    # Fetch all active (non-suspended) officers with their profiles
    result = await db.execute(
        select(User, Officer)
        .join(Officer, Officer.user_id == User.id)
        .where(User.role == UserRole.officer, User.is_suspended == False)
    )
    rows = result.all()

    candidates = []
    for user, officer in rows:
        if officer.jurisdiction_geojson and _point_in_polygon(lat, lng, officer.jurisdiction_geojson):
            candidates.append((user, officer))

    if not candidates:
        logger.warning(f"No officer found with matching jurisdiction for ({lat}, {lng})")
        return None

    if severity == "high":
        # Pick jurisdiction match with lowest workload regardless
        candidates.sort(key=lambda x: x[1].workload_count)
        return candidates[0][0]

    # Normal: prefer lowest workload
    candidates.sort(key=lambda x: x[1].workload_count)
    return candidates[0][0]


async def assign_complaint(
    complaint: Complaint,
    db: AsyncSession,
    admin_id: Optional[str] = None,
    force_officer_id: Optional[str] = None,
) -> bool:
    """
    Assign complaint to an officer.
    If force_officer_id is set (admin reassignment), skip auto-selection.
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
            raise ValueError("Target officer not found or suspended.")
    else:
        officer = await find_best_officer(
            complaint.location_lat,
            complaint.location_lng,
            complaint.severity.value if complaint.severity else "medium",
            db,
        )

    if not officer:
        return False

    # Update old officer workload if reassigning
    if complaint.assigned_officer_id and complaint.assigned_officer_id != officer.id:
        await db.execute(
            update(Officer)
            .where(Officer.user_id == complaint.assigned_officer_id)
            .values(workload_count=Officer.workload_count - 1)
        )

    # Assign
    complaint.assigned_officer_id = officer.id
    complaint.status = ComplaintStatus.assigned
    complaint.assigned_at = datetime.now(timezone.utc)

    # Increment new officer workload
    await db.execute(
        update(Officer)
        .where(Officer.user_id == officer.id)
        .values(workload_count=Officer.workload_count + 1)
    )

    # Audit
    db.add(AuditLog(
        actor_id=uuid.UUID(admin_id) if admin_id else None,
        action="complaint_assigned",
        target_type="complaint",
        target_id=str(complaint.id),
        metadata={
            "officer_id": str(officer.id),
            "officer_name": officer.name,
            "auto_assigned": force_officer_id is None,
        },
    ))

    logger.info(f"Complaint {complaint.id} assigned to officer {officer.id}")
    return True
