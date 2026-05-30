"""
Evaluate a trained road damage model on a folder of test images.
Useful for checking accuracy on new/local images outside the RDD2022 set.

Usage:
  python -m ai.evaluate \
    --model  ./models/road_damage.keras \
    --images ./test_images/

Each image filename can optionally encode the true label:
  pothole_001.jpg  →  label = "pothole"
  crack_002.jpg    →  label = "crack"
Otherwise unlabelled images are still classified and shown.
"""

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


DAMAGE_TYPES   = ["pothole", "crack", "waterlogging", "damaged_road", "other"]
SEVERITY_LEVELS = ["low", "medium", "high"]
IMG_SIZE = (224, 224)


def load_model(model_path: str):
    import tensorflow as tf
    model = tf.keras.models.load_model(model_path)
    print(f"[evaluate] Loaded model from {model_path}")
    return model


def preprocess(image_path: str) -> np.ndarray:
    img = Image.open(image_path).convert("RGB")
    img = img.resize(IMG_SIZE, Image.BILINEAR)
    arr = np.array(img, dtype=np.float32) / 255.0
    return np.expand_dims(arr, axis=0)


def predict(model, image_path: str) -> dict:
    x = preprocess(image_path)
    preds = model.predict(x, verbose=0)

    dt_probs = preds["damage_type"][0]
    sv_probs = preds["severity"][0]

    dt_idx = int(np.argmax(dt_probs))
    sv_idx = int(np.argmax(sv_probs))

    return {
        "image":       image_path,
        "damage_type": DAMAGE_TYPES[dt_idx],
        "severity":    SEVERITY_LEVELS[sv_idx],
        "confidence":  round(float(dt_probs[dt_idx]), 4),
        "dt_probs":    {k: round(float(v), 4) for k, v in zip(DAMAGE_TYPES, dt_probs)},
        "sv_probs":    {k: round(float(v), 4) for k, v in zip(SEVERITY_LEVELS, sv_probs)},
    }


def run(args: argparse.Namespace) -> None:
    model = load_model(args.model)

    image_dir = Path(args.images)
    image_files = sorted(
        list(image_dir.glob("*.jpg")) +
        list(image_dir.glob("*.jpeg")) +
        list(image_dir.glob("*.png"))
    )

    if not image_files:
        print(f"[evaluate] No images found in {image_dir}")
        return

    results = []
    correct_dt, total_labelled = 0, 0

    for img_path in image_files:
        result = predict(model, str(img_path))

        # Try to extract ground-truth label from filename
        stem = img_path.stem.lower()
        true_label = None
        for dt in DAMAGE_TYPES:
            if stem.startswith(dt):
                true_label = dt
                break

        result["true_label"] = true_label
        if true_label:
            total_labelled += 1
            if true_label == result["damage_type"]:
                correct_dt += 1

        results.append(result)

        status = ""
        if true_label:
            ok = "✓" if true_label == result["damage_type"] else "✗"
            status = f" [{ok} true={true_label}]"

        print(
            f"  {img_path.name:<35} "
            f"type={result['damage_type']:<12} "
            f"sev={result['severity']:<6} "
            f"conf={result['confidence']:.2f}"
            f"{status}"
        )

    if total_labelled > 0:
        acc = correct_dt / total_labelled
        print(f"\n[evaluate] Labelled images: {total_labelled}")
        print(f"[evaluate] Damage-type accuracy: {acc:.2%}")

    # Save results
    out_path = Path(args.output)
    out_path.write_text(json.dumps(results, indent=2))
    print(f"[evaluate] Results saved to {out_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model",  required=True, help="Path to .keras model file")
    parser.add_argument("--images", required=True, help="Directory of test images")
    parser.add_argument("--output", default="./evaluation_results.json")
    run(parser.parse_args())
