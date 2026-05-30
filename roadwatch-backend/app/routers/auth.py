import logging
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.models import User, UserRole, AuditLog
from app.schemas.schemas import (
    PhoneCheckRequest, PhoneCheckResponse,
    CitizenRegisterRequest, FirebaseLoginRequest,
    TokenResponse, RefreshRequest,
)
from app.services.firebase_service import verify_firebase_token
from app.services.jwt_service import (
    create_access_token, create_refresh_token, rotate_refresh_token
)
from app.middleware.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["auth"])


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    return forwarded.split(",")[0].strip() if forwarded else request.client.host


# ── POST /auth/check-phone ────────────────────────────────────────────────────

@router.post("/check-phone", response_model=PhoneCheckResponse)
async def check_phone(
    body: PhoneCheckRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Step 1 of login flow — app calls this before triggering Firebase OTP.
    Returns account status so the app knows which screen to show next:
      'new'       → citizen registration flow
      'citizen'   → existing citizen, proceed to OTP login
      'officer'   → existing officer, proceed to OTP login
      'suspended' → account blocked
    """
    result = await db.execute(
        select(User).where(User.phone_number == body.phone_number)
    )
    user = result.scalar_one_or_none()

    if not user:
        return PhoneCheckResponse(phone_number=body.phone_number, status="new")

    if user.is_suspended:
        return PhoneCheckResponse(
            phone_number=body.phone_number, status="suspended", role=user.role
        )

    return PhoneCheckResponse(
        phone_number=body.phone_number,
        status=user.role.value,
        role=user.role,
    )


# ── POST /auth/login ──────────────────────────────────────────────────────────

@router.post("/login", response_model=TokenResponse)
async def login(
    body: FirebaseLoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Step 2 for existing users (citizen or officer).
    App sends Firebase ID token obtained after OTP verification on device.
    Backend verifies token, looks up user, returns JWT pair.
    """
    try:
        firebase_data = await verify_firebase_token(body.firebase_id_token)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))

    phone = firebase_data["phone_number"]

    result = await db.execute(select(User).where(User.phone_number == phone))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account found for this number. Citizens can register; officer accounts are created by admin.",
        )

    if user.is_suspended:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account suspended. Contact your administrator.",
        )

    access_token = create_access_token(str(user.id), user.role.value, user.name)
    refresh_token = await create_refresh_token(str(user.id), db)

    db.add(AuditLog(
        actor_id=user.id,
        action="login",
        target_type="user",
        target_id=str(user.id),
        ip_address=_client_ip(request),
        extra_data={"role": user.role.value},
    ))

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        role=user.role,
        user_id=str(user.id),
        name=user.name,
    )


# ── POST /auth/register ───────────────────────────────────────────────────────

@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register_citizen(
    body: CitizenRegisterRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    New citizen self-registration.
    App sends Firebase ID token (OTP already verified on device) plus name.
    Officers CANNOT use this endpoint — officer accounts are created by admin only.
    """
    try:
        firebase_data = await verify_firebase_token(body.firebase_id_token)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))

    if firebase_data["phone_number"] != body.phone_number:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number mismatch between form and Firebase token.",
        )

    existing = await db.execute(
        select(User).where(User.phone_number == body.phone_number)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this phone number already exists.",
        )

    user = User(
        phone_number=body.phone_number,
        name=body.name.strip(),
        role=UserRole.citizen,
        trust_score=100,
    )
    db.add(user)
    await db.flush()

    access_token = create_access_token(str(user.id), user.role.value, user.name)
    refresh_token = await create_refresh_token(str(user.id), db)

    db.add(AuditLog(
        actor_id=user.id,
        action="citizen_registered",
        target_type="user",
        target_id=str(user.id),
        ip_address=_client_ip(request),
        extra_data={"name": user.name, "phone": user.phone_number},
    ))

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        role=user.role,
        user_id=str(user.id),
        name=user.name,
    )


# ── POST /auth/refresh ────────────────────────────────────────────────────────

@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    body: RefreshRequest,
    db: AsyncSession = Depends(get_db),
):
    """Rotate refresh token and return a new access + refresh pair."""
    try:
        new_access, new_refresh = await rotate_refresh_token(body.refresh_token, db)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))

    from app.services.jwt_service import decode_access_token
    payload = decode_access_token(new_access)

    return TokenResponse(
        access_token=new_access,
        refresh_token=new_refresh,
        role=payload["role"],
        user_id=payload["sub"],
        name=payload["name"],
    )


# ── POST /auth/logout ─────────────────────────────────────────────────────────

@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    body: RefreshRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Revoke the refresh token so it cannot be used again."""
    from app.services.jwt_service import revoke_all_tokens
    await revoke_all_tokens(str(current_user.id), db)
    db.add(AuditLog(
        actor_id=current_user.id,
        action="logout",
        target_type="user",
        target_id=str(current_user.id),
    ))
