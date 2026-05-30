from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.models import User
from app.schemas.schemas import UserOut, UserProfileUpdate, UploadResponse
from app.middleware.auth import require_citizen
from app.services.storage_service import upload_image, validate_image
from app.config import settings

router = APIRouter(prefix="/citizen", tags=["citizen"])


@router.get("/profile", response_model=UserOut)
async def get_profile(current_user: User = Depends(require_citizen)):
    return current_user


@router.patch("/profile", response_model=UserOut)
async def update_profile(
    body: UserProfileUpdate,
    current_user: User = Depends(require_citizen),
    db: AsyncSession = Depends(get_db),
):
    if body.name:
        current_user.name = body.name.strip()
    if body.avatar_url is not None:
        current_user.avatar_url = body.avatar_url
    return current_user


@router.post("/profile/avatar", response_model=UploadResponse)
async def upload_avatar(
    image: UploadFile = File(...),
    current_user: User = Depends(require_citizen),
    db: AsyncSession = Depends(get_db),
):
    file_bytes = await image.read()
    validate_image(file_bytes, max_size_mb=5.0)
    result = await upload_image(
        file_bytes, image.filename or "avatar.jpg",
        settings.STORAGE_BUCKET_AVATARS,
    )
    current_user.avatar_url = result["url"]
    return UploadResponse(url=result["url"], path=result["path"])
