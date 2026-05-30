import uuid
import logging
from typing import Optional

from supabase import create_client, Client
from app.config import settings

logger = logging.getLogger(__name__)

_supabase_client: Optional[Client] = None


def get_supabase() -> Client:
    global _supabase_client
    if _supabase_client is None:
        _supabase_client = create_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_SERVICE_ROLE_KEY,
        )
    return _supabase_client


def _upload_blocking(file_bytes: bytes, unique_path: str, bucket: str,
                     content_type: str) -> str:
    """Blocking Supabase upload — runs in a worker thread."""
    client = get_supabase()
    client.storage.from_(bucket).upload(
        path=unique_path,
        file=file_bytes,
        file_options={"content-type": content_type, "upsert": "false"},
    )
    return client.storage.from_(bucket).get_public_url(unique_path)


async def upload_image(
    file_bytes: bytes,
    filename: str,
    bucket: str,
    content_type: str = "image/jpeg",
) -> dict:
    """
    Upload a file to Supabase Storage. Returns {'url': ..., 'path': ...}.

    The Supabase Python client is synchronous/blocking, so the upload runs
    in a worker thread via asyncio.to_thread to avoid blocking the event loop
    (which would stall every other concurrent request).
    """
    import asyncio
    ext = filename.rsplit(".", 1)[-1] if "." in filename else "jpg"
    unique_path = f"{uuid.uuid4()}.{ext}"

    try:
        public_url = await asyncio.to_thread(
            _upload_blocking, file_bytes, unique_path, bucket, content_type
        )
        return {"url": public_url, "path": unique_path}
    except Exception as e:
        logger.error(f"Supabase upload failed — bucket={bucket} error={e}")
        raise RuntimeError(f"Image upload failed: {str(e)}")


async def delete_file(path: str, bucket: str) -> bool:
    """Delete a file from Supabase Storage."""
    try:
        client = get_supabase()
        client.storage.from_(bucket).remove([path])
        return True
    except Exception as e:
        logger.warning(f"Supabase delete failed — path={path} error={e}")
        return False


def validate_image(file_bytes: bytes, max_size_mb: float = 10.0) -> None:
    """Raise ValueError if the file is too large or not a recognised image format."""
    max_bytes = int(max_size_mb * 1024 * 1024)
    if len(file_bytes) > max_bytes:
        raise ValueError(f"Image must be under {max_size_mb} MB.")

    is_jpeg = file_bytes[:3] == b"\xff\xd8\xff"
    is_png  = file_bytes[:8] == b"\x89PNG\r\n\x1a\n"
    is_webp = (file_bytes[:4] == b"RIFF") and (file_bytes[8:12] == b"WEBP")

    if not (is_jpeg or is_png or is_webp):
        raise ValueError("Only JPEG, PNG, or WebP images are accepted.")
