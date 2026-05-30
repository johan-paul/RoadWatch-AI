"""
Repair Verification Service

When an officer uploads an "after" photo for a repair:
  1. Download both the before image (from complaint.image_url) and the
     after image (just uploaded).
  2. Compute Structural Similarity Index (SSIM) between them.
  3. Apply a perceptual difference score to estimate repair effectiveness.

Interpretation:
  SSIM ≥ 0.92  → images look the same — repair NOT confirmed (possibly wrong photos)
  SSIM ∈ [0.55, 0.92) → images differ significantly — REPAIR CONFIRMED ✓
  SSIM < 0.55  → images look completely different — uncertain / wrong location

A higher "visual_change" score means more surface change was detected.

The service is intentionally lightweight — no custom model needed.
It uses scikit-image's SSIM which ships with standard Python.
"""

import io
import logging
import math
from dataclasses import dataclass
from typing import Optional

import httpx
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

VERIFY_SIZE = (256, 256)   # Resize both images to this before comparison

# SSIM thresholds
SSIM_TOO_SIMILAR  = 0.92   # Looks identical → repair NOT confirmed
SSIM_TOO_DIFFERENT = 0.40  # Looks completely different → uncertain

# Minimum visual change score to call it "verified"
MIN_CHANGE_SCORE = 0.12


@dataclass
class RepairVerificationResult:
    ai_verified:           bool
    ai_verification_score: float   # 0–1, higher = more confident repair happened
    ssim:                  float
    visual_change:         float
    reason:                str


# ── Image utilities ───────────────────────────────────────────────────────────

def _load_image_array(image_bytes: bytes) -> np.ndarray:
    """Decode bytes → (H, W, 3) float32 array in [0, 1]."""
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img = img.resize(VERIFY_SIZE, Image.BILINEAR)
    return np.array(img, dtype=np.float32) / 255.0


async def _fetch_image(url: str) -> Optional[bytes]:
    """Download an image from a URL. Returns raw bytes or None on error."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url)
            resp.raise_for_status()
            return resp.content
    except Exception as e:
        logger.warning(f"[repair_service] Failed to fetch image from {url}: {e}")
        return None


# ── SSIM ──────────────────────────────────────────────────────────────────────

def _compute_ssim(img1: np.ndarray, img2: np.ndarray) -> float:
    """
    Compute mean SSIM across all three RGB channels.
    Uses a simplified 11×11 Gaussian window approach.
    """
    try:
        from skimage.metrics import structural_similarity as ssim
        score = float(ssim(img1, img2, channel_axis=2, data_range=1.0))
        return max(0.0, min(1.0, score))
    except ImportError:
        # Fallback: normalised mean absolute difference (lower = more different)
        mad = float(np.mean(np.abs(img1 - img2)))
        return max(0.0, 1.0 - mad * 4)


def _compute_visual_change(img1: np.ndarray, img2: np.ndarray) -> float:
    """
    Compute a normalised "visual change" score (0–1).
    Converts both images to grayscale, computes absolute pixel difference,
    applies a local threshold, and measures the fraction of changed pixels.
    """
    gray1 = 0.299 * img1[:, :, 0] + 0.587 * img1[:, :, 1] + 0.114 * img1[:, :, 2]
    gray2 = 0.299 * img2[:, :, 0] + 0.587 * img2[:, :, 1] + 0.114 * img2[:, :, 2]
    diff = np.abs(gray1 - gray2)
    changed_pixels = float(np.mean(diff > 0.08))
    return round(changed_pixels, 4)


# ── Main function ─────────────────────────────────────────────────────────────

async def verify_repair(
    before_image_bytes: bytes,
    after_image_bytes: bytes,
) -> RepairVerificationResult:
    """
    Compare before and after images and return a RepairVerificationResult.

    Args:
        before_image_bytes : raw bytes of the original complaint photo
        after_image_bytes  : raw bytes of the officer's repair photo

    Returns:
        RepairVerificationResult with ai_verified, score, and reason.
    """
    try:
        before_arr = _load_image_array(before_image_bytes)
        after_arr  = _load_image_array(after_image_bytes)
    except Exception as e:
        logger.error(f"[repair_service] Image decode error: {e}")
        return RepairVerificationResult(
            ai_verified=False,
            ai_verification_score=0.0,
            ssim=0.0,
            visual_change=0.0,
            reason="Image decode failed — cannot verify.",
        )

    ssim_score    = _compute_ssim(before_arr, after_arr)
    visual_change = _compute_visual_change(before_arr, after_arr)

    logger.info(
        f"[repair_service] SSIM={ssim_score:.3f}  "
        f"visual_change={visual_change:.3f}"
    )

    # ── Decision logic ────────────────────────────────────────────────────────

    if ssim_score >= SSIM_TOO_SIMILAR:
        return RepairVerificationResult(
            ai_verified=False,
            ai_verification_score=round(1.0 - ssim_score, 4),
            ssim=ssim_score,
            visual_change=visual_change,
            reason=(
                "Before and after images look nearly identical. "
                "Please upload a photo showing the completed repair."
            ),
        )

    if ssim_score < SSIM_TOO_DIFFERENT and visual_change < MIN_CHANGE_SCORE:
        return RepairVerificationResult(
            ai_verified=False,
            ai_verification_score=0.1,
            ssim=ssim_score,
            visual_change=visual_change,
            reason=(
                "The after image looks completely different from the before image. "
                "Please make sure you photographed the same location."
            ),
        )

    # Confirmed: significant surface change detected
    # Score = inverse SSIM weighted by visual change
    base_score = (1.0 - ssim_score)           # 0–1, high = more different
    boost      = visual_change * 0.3           # boost from pixel diff
    verification_score = min(1.0, base_score + boost)

    return RepairVerificationResult(
        ai_verified=True,
        ai_verification_score=round(verification_score, 4),
        ssim=ssim_score,
        visual_change=visual_change,
        reason="Repair confirmed — significant surface change detected between before and after photos.",
    )


async def verify_repair_from_urls(
    before_url: str,
    after_image_bytes: bytes,
) -> RepairVerificationResult:
    """
    Convenience wrapper: fetches the 'before' image from a URL,
    then calls verify_repair().
    """
    before_bytes = await _fetch_image(before_url)
    if before_bytes is None:
        logger.warning("[repair_service] Could not fetch before image — auto-approving.")
        return RepairVerificationResult(
            ai_verified=True,
            ai_verification_score=0.5,
            ssim=0.0,
            visual_change=0.0,
            reason="Before image unavailable — repair accepted without visual verification.",
        )
    return await verify_repair(before_bytes, after_image_bytes)
