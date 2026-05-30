"""
Duplicate Complaint Detection Service

A new complaint is flagged as a duplicate when ALL of the following hold:
  1. Same damage_type (or both are None)
  2. Within RADIUS_METERS of an existing complaint
  3. That existing complaint is not already resolved / rejected / duplicate
  4. Created within LOOKBACK_DAYS

When a duplicate is detected:
  - complaint.is_duplicate = True
  - complaint.duplicate_of  = <original complaint id>
  - complaint.status        = "duplicate"

Haversine formula is used for distance — no PostGIS required.
"""

import logging
import math
from datetime import datetime, timezone, timedelta
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.models import Complaint, ComplaintStatus

logger = logging.getLogger(__name__)

# ── Config ────────────────────────────────────────────────────────────────────
RADIUS_METERS  = 75      # Flag as duplicate if within this radius
LOOKBACK_DAYS  = 30      # Only look back this many days
SKIP_STATUSES  = {       # Ignore complaints in these terminal states
    ComplaintStatus.resolved,
    ComplaintStatus.rejected,
    ComplaintStatus.duplicate,
}


# ── Haversine ─────────────────────────────────────────────────────────────────

def _haversine_meters(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Compute the great-circle distance in metres between two (lat, lng) points."""
    R = 6_371_000  # Earth radius in metres
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


# ── Main function ─────────────────────────────────────────────────────────────

async def check_and_mark_duplicate(
    complaint: Complaint,
    db: AsyncSession,
) -> bool:
    """
    Check if `complaint` is a near-duplicate of an existing open complaint.
    Mutates complaint in-place if a duplicate is found.
    Returns True if marked as duplicate.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=LOOKBACK_DAYS)

    # Fetch existing open complaints (within a bounding box first for speed)
    lat_margin = RADIUS_METERS / 111_320  # ~1 degree lat = 111,320 m
    lng_margin = RADIUS_METERS / (111_320 * math.cos(math.radians(complaint.location_lat)))

    result = await db.execute(
        select(Complaint).where(
            Complaint.id != complaint.id,
            Complaint.status.not_in(list(SKIP_STATUSES)),
            Complaint.created_at >= cutoff,
            Complaint.location_lat.between(
                complaint.location_lat - lat_margin,
                complaint.location_lat + lat_margin,
            ),
            Complaint.location_lng.between(
                complaint.location_lng - lng_margin,
                complaint.location_lng + lng_margin,
            ),
        )
    )
    nearby = result.scalars().all()

    for existing in nearby:
        dist = _haversine_meters(
            complaint.location_lat, complaint.location_lng,
            existing.location_lat,  existing.location_lng,
        )
        if dist > RADIUS_METERS:
            continue

        # Same damage type (or both None)
        same_type = (complaint.damage_type == existing.damage_type) or \
                    (complaint.damage_type is None and existing.damage_type is None)
        if not same_type:
            continue

        # Duplicate found
        complaint.is_duplicate = True
        complaint.duplicate_of = existing.id
        complaint.status       = ComplaintStatus.duplicate

        logger.info(
            f"[duplicate] Complaint {complaint.id} is a duplicate of "
            f"{existing.id} (distance={dist:.0f}m, type={existing.damage_type})"
        )
        return True

    return False
