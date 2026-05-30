"""
RDD2022 YOLO-format dataset loader for RoadWatch AI.

Expected folder structure (already pre-split):
  data/RDD_SPLIT/
    train/
      images/   *.jpg
      labels/   *.txt   (YOLO format: class_id cx cy w h, normalized)
    val/
      images/
      labels/
    test/
      images/
      labels/

YOLO class → damage type mapping:
  0  D00  Longitudinal Crack  → crack
  1  D01  Transverse Crack    → crack
  2  D10  Alligator Crack     → crack
  3  D11  Pothole             → pothole
  4  D40  Rutting / Bump      → damaged_road
  (empty file)               → other   (no damage in image)

Severity is inferred from the largest bounding-box area in the image:
  area (w×h) ≥ 0.08  → high
  area (w×h) ∈ [0.02, 0.08) → medium
  area (w×h) < 0.02  → low
  (empty / other)    → low
"""

import os
import random
from collections import Counter
from pathlib import Path
from typing import Optional

# ── Constants ─────────────────────────────────────────────────────────────────

DAMAGE_TYPES    = ["pothole", "crack", "waterlogging", "damaged_road", "other"]
SEVERITY_LEVELS = ["low", "medium", "high"]
IMG_SIZE        = (224, 224)

# YOLO class id → our damage type
YOLO_CLASS_MAP: dict[int, str] = {
    0: "crack",
    1: "crack",
    2: "crack",
    3: "pothole",
    4: "damaged_road",
}


# ── YOLO label parser ─────────────────────────────────────────────────────────

def _parse_yolo_label(label_path: str) -> dict:
    """
    Parse one YOLO .txt label file.
    Returns:
      {
        "damage_type": str,   # dominant class in the image
        "severity":    str,   # inferred from largest bbox area
        "num_objects": int
      }
    Empty file → damage_type="other", severity="low"
    """
    path = Path(label_path)
    if not path.exists() or path.stat().st_size == 0:
        return {"damage_type": "other", "severity": "low", "num_objects": 0}

    class_ids   = []
    max_area    = 0.0

    for line in path.read_text().splitlines():
        parts = line.strip().split()
        if len(parts) < 5:
            continue
        cls_id = int(parts[0])
        w, h   = float(parts[3]), float(parts[4])
        area   = w * h

        class_ids.append(cls_id)
        max_area = max(max_area, area)

    if not class_ids:
        return {"damage_type": "other", "severity": "low", "num_objects": 0}

    # Dominant class = most frequent YOLO id → mapped damage type
    dominant_id = Counter(class_ids).most_common(1)[0][0]
    damage_type = YOLO_CLASS_MAP.get(dominant_id, "other")

    # Severity from largest bbox
    if max_area >= 0.08:
        severity = "high"
    elif max_area >= 0.02:
        severity = "medium"
    else:
        severity = "low"

    return {
        "damage_type": damage_type,
        "severity":    severity,
        "num_objects": len(class_ids),
    }


# ── Dataset builder ───────────────────────────────────────────────────────────

def build_dataset(
    data_root: str,
    countries: Optional[list[str]] = None,
    max_per_class: int = 3000,
    seed: int = 42,
) -> tuple[list[dict], list[dict], list[dict]]:
    """
    Load the pre-split RDD_SPLIT dataset and return
    (train_samples, val_samples, test_samples).

    Each sample: { "image_path": str, "damage_type": str, "severity": str }

    Args:
        data_root:     Path to the folder containing RDD_SPLIT/
        countries:     Filter by country prefix e.g. ["India", "Japan"].
                       None = use all countries.
        max_per_class: Cap samples per damage-type class for balance.
        seed:          Random seed.
    """
    random.seed(seed)
    rdd_split = Path(data_root) / "RDD_SPLIT"

    if not rdd_split.exists():
        # Also allow data_root to point directly to RDD_SPLIT
        rdd_split = Path(data_root)
        if not (rdd_split / "train").exists():
            raise FileNotFoundError(
                f"Cannot find RDD_SPLIT/ inside {data_root}. "
                f"Make sure the folder structure is:\n"
                f"  {data_root}/RDD_SPLIT/train/images/\n"
                f"  {data_root}/RDD_SPLIT/train/labels/"
            )

    train_samples = _load_split(rdd_split / "train", countries, "train")
    val_samples   = _load_split(rdd_split / "val",   countries, "val")
    test_samples  = _load_split(rdd_split / "test",  countries, "test")

    # Balance only training set
    train_samples = _balance(train_samples, max_per_class, seed)

    _print_stats("train", train_samples)
    _print_stats("val",   val_samples)
    _print_stats("test",  test_samples)

    return train_samples, val_samples, test_samples


def _load_split(
    split_dir: Path,
    countries: Optional[list[str]],
    split_name: str,
) -> list[dict]:
    img_dir   = split_dir / "images"
    label_dir = split_dir / "labels"

    if not img_dir.exists():
        print(f"[dataset] Warning: {img_dir} not found — skipping.")
        return []

    image_files = sorted(img_dir.glob("*.jpg")) + sorted(img_dir.glob("*.png"))

    # Country filter
    if countries:
        filtered = []
        for f in image_files:
            for c in countries:
                if f.name.startswith(c + "_"):
                    filtered.append(f)
                    break
        image_files = filtered

    samples = []
    for img_path in image_files:
        label_path = label_dir / (img_path.stem + ".txt")
        ann = _parse_yolo_label(str(label_path))
        samples.append({
            "image_path":  str(img_path),
            "damage_type": ann["damage_type"],
            "severity":    ann["severity"],
        })

    print(f"[dataset] {split_name}: loaded {len(samples)} images"
          + (f" (countries={countries})" if countries else ""))
    return samples


def _balance(samples: list[dict], max_per_class: int, seed: int) -> list[dict]:
    """Cap each damage-type class to max_per_class samples."""
    random.seed(seed)
    from collections import defaultdict
    by_class: dict[str, list[dict]] = defaultdict(list)
    for s in samples:
        by_class[s["damage_type"]].append(s)

    balanced = []
    for cls, items in by_class.items():
        random.shuffle(items)
        balanced.extend(items[:max_per_class])

    random.shuffle(balanced)
    return balanced


def _print_stats(name: str, samples: list[dict]) -> None:
    print(f"\n[dataset] {name} split - {len(samples)} samples:")
    counts = Counter(s["damage_type"] for s in samples)
    for dt in DAMAGE_TYPES:
        n = counts.get(dt, 0)
        bar = "#" * (n // 50)
        print(f"  {dt:<15} {n:>5}  {bar}")


# ── tf.data pipeline ──────────────────────────────────────────────────────────

def make_tf_datasets(
    train_samples: list[dict],
    val_samples:   list[dict],
    test_samples:  list[dict],
    batch_size:    int = 32,
    augment_train: bool = True,
):
    """
    Convert sample lists into tf.data.Dataset objects.
    Returns (train_ds, val_ds, test_ds).
    """
    import tensorflow as tf

    dt_index = {v: i for i, v in enumerate(DAMAGE_TYPES)}
    sv_index = {v: i for i, v in enumerate(SEVERITY_LEVELS)}

    def _load(path, dt_lbl, sv_lbl):
        img = tf.io.read_file(path)
        img = tf.image.decode_jpeg(img, channels=3)
        img = tf.image.resize(img, IMG_SIZE)
        img = tf.cast(img, tf.float32) / 255.0
        return img, {"damage_type": dt_lbl, "severity": sv_lbl}

    def _augment(img, labels):
        img = tf.image.random_flip_left_right(img)
        img = tf.image.random_flip_up_down(img)
        img = tf.image.random_brightness(img, max_delta=0.2)
        img = tf.image.random_contrast(img, lower=0.75, upper=1.25)
        img = tf.image.random_saturation(img, lower=0.75, upper=1.25)
        img = tf.image.random_hue(img, max_delta=0.05)
        # Zoom simulation
        crop_h = int(IMG_SIZE[0] * 0.85)
        crop_w = int(IMG_SIZE[1] * 0.85)
        img = tf.image.random_crop(img, size=(crop_h, crop_w, 3))
        img = tf.image.resize(img, IMG_SIZE)
        img = tf.clip_by_value(img, 0.0, 1.0)
        return img, labels

    def _make_ds(samples: list[dict], shuffle: bool, augment: bool):
        paths   = [s["image_path"]              for s in samples]
        dt_lbls = [dt_index[s["damage_type"]]   for s in samples]
        sv_lbls = [sv_index[s["severity"]]       for s in samples]

        ds = tf.data.Dataset.from_tensor_slices((paths, dt_lbls, sv_lbls))
        ds = ds.map(_load, num_parallel_calls=tf.data.AUTOTUNE)
        if shuffle:
            ds = ds.shuffle(buffer_size=min(len(samples), 8000), seed=42)
        if augment:
            ds = ds.map(_augment, num_parallel_calls=tf.data.AUTOTUNE)
        ds = ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)
        return ds

    train_ds = _make_ds(train_samples, shuffle=True,  augment=augment_train)
    val_ds   = _make_ds(val_samples,   shuffle=False, augment=False)
    test_ds  = _make_ds(test_samples,  shuffle=False, augment=False)

    return train_ds, val_ds, test_ds
