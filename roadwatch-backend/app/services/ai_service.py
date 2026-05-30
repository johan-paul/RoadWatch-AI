"""
RoadWatch AI — Road Damage Inference Service (TensorFlow/Keras)

Loads the trained Keras model at server startup and runs inference
on every complaint image submitted by citizens.

Graceful degradation: if the model file doesn't exist yet, the server
still starts and complaints go through with default values (severity=medium,
damage_type=None) until the model is trained and placed in models/.

Input preprocessing:
  - Resize to 224×224
  - Normalise to [0, 1]
  - The model internally rescales to [0, 255] via its Rescaling(255.0) layer

Outputs:
  damage_type      : pothole | crack | waterlogging | damaged_road | other
  severity         : low | medium | high
  confidence_score : 0–1 (max softmax probability for damage_type)
  risk_score       : type_risk × severity_weight × confidence
"""

import io
import logging
from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

# ── Class labels (must match training order in dataset.py) ────────────────────
DAMAGE_TYPES    = ["pothole", "crack", "waterlogging", "damaged_road", "other"]
SEVERITY_LEVELS = ["low", "medium", "high"]
IMG_SIZE        = (224, 224)

TYPE_RISK: dict[str, float] = {
    "pothole":      0.90,
    "damaged_road": 0.80,
    "waterlogging": 0.70,
    "crack":        0.60,
    "other":        0.25,
}
SEVERITY_WEIGHT: dict[str, float] = {
    "high":   1.00,
    "medium": 0.60,
    "low":    0.30,
}
CONFIDENCE_THRESHOLD = 0.40


# ── Result dataclass ──────────────────────────────────────────────────────────

@dataclass
class AIAnalysisResult:
    damage_type:      str
    severity:         str
    confidence_score: float
    risk_score:       float
    raw:              dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "damage_type":      self.damage_type,
            "severity":         self.severity,
            "confidence_score": round(self.confidence_score, 4),
            "risk_score":       round(self.risk_score, 4),
            "raw":              self.raw,
        }


# ── Classifier ────────────────────────────────────────────────────────────────

class RoadDamageClassifier:
    def __init__(self) -> None:
        self._model = None

    def load(self, model_path: str) -> bool:
        """Load the .keras model from disk. Returns True on success."""
        try:
            import tensorflow as tf
            self._model = tf.keras.models.load_model(model_path)
            logger.info(f"[ai_service] Model loaded from {model_path}")
            return True
        except FileNotFoundError:
            logger.warning(
                f"[ai_service] Model not found at {model_path}. "
                "Run 'python -m ai.train' to train it first. "
                "Complaints will use default values until then."
            )
        except ImportError:
            logger.warning("[ai_service] TensorFlow not installed.")
        except Exception as e:
            logger.error(f"[ai_service] Model load error: {e}", exc_info=True)
        return False

    @property
    def is_loaded(self) -> bool:
        return self._model is not None

    def _preprocess(self, image_bytes: bytes) -> np.ndarray:
        """
        Decode image bytes → (1, 224, 224, 3) float32 in [0, 1].
        The model's Rescaling(255.0) layer handles the rest internally.
        """
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        img = img.resize(IMG_SIZE, Image.BILINEAR)
        arr = np.array(img, dtype=np.float32) / 255.0
        return np.expand_dims(arr, axis=0)   # (1, 224, 224, 3)

    def predict(self, image_bytes: bytes) -> Optional[AIAnalysisResult]:
        if not self.is_loaded:
            return None
        try:
            x     = self._preprocess(image_bytes)
            preds = self._model.predict(x, verbose=0)

            dt_probs = preds["damage_type"][0].tolist()
            sv_probs = preds["severity"][0].tolist()

            dt_idx     = int(np.argmax(dt_probs))
            sv_idx     = int(np.argmax(sv_probs))
            confidence = float(dt_probs[dt_idx])

            damage_type = (
                DAMAGE_TYPES[dt_idx]
                if confidence >= CONFIDENCE_THRESHOLD
                else "other"
            )
            severity = SEVERITY_LEVELS[sv_idx]

            risk_score = (
                TYPE_RISK.get(damage_type, 0.25)
                * SEVERITY_WEIGHT.get(severity, 0.6)
                * confidence
            )

            return AIAnalysisResult(
                damage_type=damage_type,
                severity=severity,
                confidence_score=round(confidence, 4),
                risk_score=round(risk_score, 4),
                raw={
                    "damage_type_probs": {
                        k: round(v, 4)
                        for k, v in zip(DAMAGE_TYPES, dt_probs)
                    },
                    "severity_probs": {
                        k: round(v, 4)
                        for k, v in zip(SEVERITY_LEVELS, sv_probs)
                    },
                },
            )

        except Exception as e:
            logger.error(f"[ai_service] Inference error: {e}", exc_info=True)
            return None


# ── Global singleton ──────────────────────────────────────────────────────────

_classifier = RoadDamageClassifier()


def load_model(model_path: str) -> bool:
    return _classifier.load(model_path)


def analyze_road_damage(image_bytes: bytes) -> Optional[AIAnalysisResult]:
    return _classifier.predict(image_bytes)


def boost_risk_with_density(
    base_result: AIAnalysisResult,
    nearby_count: int,
) -> AIAnalysisResult:
    """
    Boost risk_score based on nearby complaint density.
    Each nearby complaint (within 300m) adds 5% risk, capped at +30%.
    """
    if nearby_count <= 0:
        return base_result
    density_bonus = min(nearby_count * 0.05, 0.30)
    new_risk = min(base_result.risk_score + density_bonus, 1.0)
    return AIAnalysisResult(
        damage_type=base_result.damage_type,
        severity=base_result.severity,
        confidence_score=base_result.confidence_score,
        risk_score=round(new_risk, 4),
        raw={
            **base_result.raw,
            "density_bonus": density_bonus,
            "nearby_count":  nearby_count,
        },
    )


def is_model_loaded() -> bool:
    return _classifier.is_loaded
