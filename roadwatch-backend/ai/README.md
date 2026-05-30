# RoadWatch AI — Model Training Guide

This folder contains the training pipeline for the road damage classifier
that powers the AI analysis in RoadWatch.

---

## What the model does

| Output | Classes | Description |
|--------|---------|-------------|
| `damage_type` | pothole, crack, waterlogging, damaged_road, other | What kind of road damage is shown |
| `severity` | low, medium, high | How severe the damage is |
| `confidence_score` | 0–1 float | How confident the model is |
| `risk_score` | 0–1 float | Combined risk (type × severity × confidence) |

---

## Step 1 — Download the dataset (India only — ~2.2 GB)

The model is trained on **RDD2022** (Road Damage Dataset 2022).
You only need the **India subset** (~2.2 GB, ~7,000 images).
The full 4-country dataset is 12 GB — skip it.

**Direct India download:**
1. Go to https://figshare.com/articles/dataset/RDD2022/21431547
2. Download only **`India.tar.gz`** (≈ 2.2 GB)
3. Extract it into `roadwatch-backend/data/RDD2022/`:

```
roadwatch-backend/
  data/
    RDD2022/
      India/
        images/        ← .jpg files (~7,000)
        annotations/
          xmls/        ← .xml files
```

> **Optional:** Also download `Japan.tar.gz` (~4.1 GB) for more crack/pothole
> samples. Not necessary — India alone gives 80%+ accuracy.

> **Kaggle alternative (faster download):**
> Search "Road Damage Detection RDD2022 India" on Kaggle.
> Several users have re-uploaded the India subset as a standalone dataset.

---

## Step 2 — (Optional) Add waterlogging images

RDD2022 does not include waterlogging images.
Create a custom folder and drop in labelled photos:

```
data/RDD2022/custom/waterlogging/
  waterlog_001.jpg
  waterlog_002.jpg
  ...
```

No annotation files needed — all images in this folder are automatically
labelled as `waterlogging / medium severity`.

---

## Step 3 — Install training dependencies

```bash
cd roadwatch-backend
pip install tensorflow==2.17.0 scikit-learn scikit-image pillow numpy matplotlib
```

To use a GPU (strongly recommended, 5–10× faster):
```bash
pip install tensorflow[and-cuda]==2.17.0
```

---

## Step 4 — Train the model

**Option A: Local (with GPU)**
```bash
cd roadwatch-backend
python -m ai.train \
  --data_root  ./data/RDD2022 \
  --output     ./models/road_damage.keras \
  --countries  India \
  --backbone   EfficientNetB0 \
  --epochs1    20 \
  --epochs2    10
```

**Option B: Google Colab (free GPU — recommended)**

1. Go to https://colab.research.google.com → New notebook
2. Upload `India.tar.gz` to your Google Drive
3. Create a new cell and run:

```python
# Mount Drive
from google.colab import drive
drive.mount('/content/drive')

# Extract dataset
!mkdir -p /content/data/RDD2022
!tar -xzf "/content/drive/MyDrive/India.tar.gz" -C /content/data/RDD2022/

# Clone just the AI scripts (or upload them manually)
!pip install tensorflow scikit-learn scikit-image -q

# Upload dataset.py, model.py, train.py to /content/
# Then run:
!python train.py \
  --data_root /content/data/RDD2022 \
  --output    /content/drive/MyDrive/road_damage.keras \
  --countries India \
  --epochs1   20 \
  --epochs2   10
```

4. Copy `road_damage.keras` from Drive → `roadwatch-backend/models/`

**Training time estimates (India-only, ~7,000 images):**
| Hardware | Phase 1 | Phase 2 | Total |
|----------|---------|---------|-------|
| CPU only | ~1.5 h | ~45 min | ~2.5 h |
| Colab T4 GPU | ~8 min | ~5 min | ~13 min |
| RTX 3060 | ~4 min | ~3 min | ~7 min |

---

## Step 5 — Evaluate

```bash
python -m ai.evaluate \
  --model  ./models/road_damage.keras \
  --images ./test_images/
```

Name your test images starting with the label for automatic accuracy reporting:
```
pothole_test1.jpg
crack_test2.jpg
waterlogging_test3.jpg
```

---

## Step 6 — Start the server

Once `models/road_damage.keras` exists, the backend loads it automatically on startup:

```bash
cd roadwatch-backend
uvicorn app.main:app --reload
```

Look for:
```
✓ Road damage AI model loaded from models/road_damage.keras
```

If the model file is missing, the server still starts — complaints go through
with `damage_type=null` and `severity=medium` until training is complete.

---

## Expected accuracy

After training on RDD2022 India + Japan (~10,000 images per class after balancing):

| Metric | Expected |
|--------|---------|
| damage_type accuracy | 82–88% |
| severity accuracy | 74–80% |
| Inference time (CPU) | ~45 ms/image |
| Inference time (GPU) | ~8 ms/image |

---

## Architecture summary

```
Input: 224×224 RGB image (normalized to [0,1])
  └─ EfficientNetB0 backbone (ImageNet pre-trained)
     └─ GlobalAveragePooling → BatchNorm → Dropout(0.35)
        ├─ Head 1: Dense(256) → BN → Dropout → Dense(5, softmax) [damage_type]
        └─ Head 2: Dense(128) → BN → Dropout → Dense(3, softmax) [severity]

Training: 2-phase
  Phase 1: Frozen backbone, only heads trained (Adam lr=1e-3)
  Phase 2: Top 30 backbone layers unfrozen (Adam lr=1e-5)

Loss: sparse_categorical_crossentropy
      weighted: damage_type × 1.0 + severity × 0.6
```
