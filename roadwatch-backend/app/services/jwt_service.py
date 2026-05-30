import uuid
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import jwt, JWTError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.config import settings
from app.models.models import RefreshToken, User


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


# ── Access Token ──────────────────────────────────────────────────────────────

def create_access_token(user_id: str, role: str, name: str) -> str:
    expire = _utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": user_id,
        "role": role,
        "name": name,
        "exp": expire,
        "iat": _utcnow(),
        "type": "access",
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        if payload.get("type") != "access":
            raise JWTError("Not an access token.")
        return payload
    except JWTError as e:
        raise ValueError(f"Invalid access token: {e}")


# ── Refresh Token ─────────────────────────────────────────────────────────────

def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


async def create_refresh_token(user_id: str, db: AsyncSession) -> str:
    """Issue a new refresh token, revoking any existing tokens (single-session policy)."""
    raw_token = str(uuid.uuid4())
    token_hash = _hash_token(raw_token)
    expires_at = _utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    old_tokens = await db.execute(
        select(RefreshToken).where(
            RefreshToken.user_id == uuid.UUID(user_id),
            RefreshToken.is_revoked == False,
        )
    )
    for token in old_tokens.scalars().all():
        token.is_revoked = True

    db.add(RefreshToken(
        user_id=uuid.UUID(user_id),
        token_hash=token_hash,
        expires_at=expires_at,
    ))
    await db.flush()
    return raw_token


async def rotate_refresh_token(raw_token: str, db: AsyncSession) -> tuple[str, str]:
    """
    Validate existing refresh token, revoke it, issue a new access + refresh pair.
    Returns (new_access_token, new_refresh_token).
    """
    token_hash = _hash_token(raw_token)

    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )
    stored = result.scalar_one_or_none()

    if not stored:
        raise ValueError("Refresh token not found.")
    if stored.is_revoked:
        raise ValueError("Refresh token has been revoked.")
    if stored.expires_at < _utcnow():
        raise ValueError("Refresh token has expired.")

    user_result = await db.execute(select(User).where(User.id == stored.user_id))
    user = user_result.scalar_one_or_none()
    if not user or user.is_suspended:
        raise ValueError("User not found or suspended.")

    stored.is_revoked = True
    await db.flush()

    new_access = create_access_token(str(user.id), user.role.value, user.name)
    new_refresh = await create_refresh_token(str(user.id), db)
    return new_access, new_refresh


async def revoke_all_tokens(user_id: str, db: AsyncSession) -> None:
    """Revoke all active refresh tokens for a user (called on suspend or logout)."""
    result = await db.execute(
        select(RefreshToken).where(
            RefreshToken.user_id == uuid.UUID(user_id),
            RefreshToken.is_revoked == False,
        )
    )
    for token in result.scalars().all():
        token.is_revoked = True
