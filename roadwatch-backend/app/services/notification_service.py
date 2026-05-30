"""
Push Notification Service — Firebase Cloud Messaging (FCM)

Sends push notifications to citizens and officers via FCM.

Design notes:
- All public functions accept a `token: Optional[str]` (the recipient's FCM
  device token), NOT a User object. The caller extracts `user.fcm_token`
  while the DB session is open, then schedules these as FastAPI
  BackgroundTasks so the blocking `messaging.send()` never delays the
  HTTP response.
- If `token` is None/empty, the function is a no-op (returns immediately).
- `messaging.send()` is a blocking network call; it is wrapped in a thread
  via asyncio so it never blocks the event loop when awaited directly.
"""

import asyncio
import logging
from typing import Optional

logger = logging.getLogger(__name__)


# ── Low-level FCM send (runs blocking call in a thread) ───────────────────────

def _send_fcm_blocking(token: str, title: str, body: str, data: dict | None = None) -> None:
    """Blocking FCM send — call inside asyncio.to_thread or a BackgroundTask."""
    try:
        from firebase_admin import messaging
        from app.services.firebase_service import get_firebase_app
        get_firebase_app()

        msg = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    channel_id="roadwatch_alerts",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default", badge=1)
                )
            ),
        )
        messaging.send(msg)
    except Exception as e:
        logger.warning(f"[FCM] send failed: {e}")


async def _send(token: Optional[str], title: str, body: str, data: dict | None = None) -> None:
    """Async wrapper — no-op when token missing, threaded otherwise."""
    if not token:
        return
    await asyncio.to_thread(_send_fcm_blocking, token, title, body, data)


# ── Public notification functions (token-based) ───────────────────────────────

async def notify_complaint_submitted(token: Optional[str], complaint_id: str,
                                     damage_type: str | None) -> None:
    label = damage_type.replace("_", " ").title() if damage_type else "Road damage"
    await _send(
        token,
        "Report Submitted ✅",
        f"{label} reported. Our AI has analysed it and assigned it to an officer.",
        {"type": "complaint_submitted", "complaint_id": complaint_id},
    )


async def notify_complaint_assigned(token: Optional[str], complaint_id: str,
                                    officer_name: str) -> None:
    await _send(
        token,
        "Officer Assigned 👷",
        f"{officer_name} has been assigned to your complaint.",
        {"type": "complaint_assigned", "complaint_id": complaint_id},
    )


async def notify_repair_started(token: Optional[str], complaint_id: str) -> None:
    await _send(
        token,
        "Repair Started 🔧",
        "The officer has started repairing your reported road issue.",
        {"type": "repair_started", "complaint_id": complaint_id},
    )


async def notify_complaint_resolved(token: Optional[str], complaint_id: str) -> None:
    await _send(
        token,
        "Road Fixed! ✅",
        "Great news — your reported road issue has been resolved.",
        {"type": "complaint_resolved", "complaint_id": complaint_id},
    )


async def notify_new_assignment(token: Optional[str], complaint_id: str,
                                damage_type: str | None, severity: str | None) -> None:
    label = damage_type.replace("_", " ").title() if damage_type else "Road damage"
    sev   = f" [{severity.upper()}]" if severity else ""
    await _send(
        token,
        f"New Assignment{sev} 📍",
        f"{label} has been assigned to you. Open the app to view details.",
        {"type": "new_assignment", "complaint_id": complaint_id},
    )


async def notify_emergency_escalation(token: Optional[str], complaint_id: str,
                                      damage_type: str | None, location: str | None) -> None:
    label = damage_type.replace("_", " ").title() if damage_type else "Road hazard"
    loc   = f" at {location}" if location else ""
    await _send(
        token,
        "🚨 EMERGENCY ESCALATION",
        f"Critical {label}{loc} has been escalated. Immediate action required.",
        {"type": "emergency", "complaint_id": complaint_id, "priority": "critical"},
    )


async def notify_duplicate_detected(token: Optional[str], complaint_id: str,
                                    original_id: str) -> None:
    await _send(
        token,
        "Report Received",
        "A similar complaint was already reported nearby. Your report has been logged.",
        {"type": "duplicate", "complaint_id": complaint_id, "original_id": original_id},
    )
