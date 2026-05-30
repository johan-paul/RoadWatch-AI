"""
RoadWatch AI — TensorFlow/Keras Training Script
================================================
Works locally (CPU) and on Google Colab (T4 GPU).

Usage:
  python -m ai.train

Output:
  models/road_damage.keras  — best model checkpoint (used by FastAPI)
  models/road_damage.json   — metadata (class labels, accuracy)
"""

import argparse
import json
import numpy as np
from pathlib import Path

import tensorflow as tf
from tensorflow import keras

from ai.dataset import build_dataset, make_tf_datasets, DAMAGE_TYPES, SEVERITY_LEVELS
from ai.model import build_model, unfreeze_top_layers


def train(args: argparse.Namespace) -> None:
    print(f"\n{'='*60}")
    print(f"  RoadWatch AI - Road Damage Classifier")
    print(f"  TensorFlow {tf.__version__}")
    gpus = tf.config.list_physical_devices("GPU")
    print(f"  GPU: {gpus[0].name if gpus else 'None (CPU)'}")
    print(f"{'='*60}\n")

    # ── Dataset ───────────────────────────────────────────────────────────────
    countries = args.countries.split(",") if args.countries else None
    train_s, val_s, test_s = build_dataset(
        data_root=args.data_root,
        countries=countries,
        max_per_class=args.max_per_class,
    )

    train_ds, val_ds, test_ds = make_tf_datasets(
        train_s, val_s, test_s,
        batch_size=args.batch_size,
        augment_train=True,
    )

    # ── Class distribution info ───────────────────────────────────────────────
    from collections import Counter
    dt_counts = Counter(s["damage_type"] for s in train_s)
    print(f"[train] Class distribution: {dict(dt_counts)}")

    # ── Output paths ──────────────────────────────────────────────────────────
    out_dir    = Path(args.output).parent
    keras_path = str(Path(args.output).with_suffix(".keras"))
    meta_path  = str(Path(args.output).with_suffix(".json"))
    out_dir.mkdir(parents=True, exist_ok=True)

    # ── Callbacks ─────────────────────────────────────────────────────────────
    def make_callbacks(path: str) -> list:
        return [
            keras.callbacks.ModelCheckpoint(
                filepath=path,
                monitor="val_damage_type_accuracy",
                mode="max",
                save_best_only=True,
                verbose=1,
            ),
            keras.callbacks.EarlyStopping(
                monitor="val_damage_type_accuracy",
                mode="max",
                patience=5,
                restore_best_weights=True,
                verbose=1,
            ),
            keras.callbacks.ReduceLROnPlateau(
                monitor="val_loss",
                factor=0.5,
                patience=3,
                min_lr=1e-7,
                verbose=1,
            ),
        ]

    # ── Phase 1: Frozen backbone ──────────────────────────────────────────────
    print(f"\n[Phase 1] Backbone frozen — training heads only")
    print(f"  Epochs: {args.epochs1}  |  Batch size: {args.batch_size}\n")

    model = build_model(freeze_backbone=True, learning_rate=args.lr_phase1)
    model.summary(line_length=80)

    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs1,
        callbacks=make_callbacks(keras_path),
        verbose=1,
    )

    # ── Phase 2: Fine-tune top backbone layers ────────────────────────────────
    if args.epochs2 > 0:
        print(f"\n[Phase 2] Fine-tuning top {args.unfreeze_layers} backbone layers")
        print(f"  Epochs: {args.epochs2}  |  LR: {args.lr_phase2}\n")

        model = keras.models.load_model(keras_path)
        unfreeze_top_layers(model, n_layers=args.unfreeze_layers)

        model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=args.lr_phase2),
            loss={
                "damage_type": "sparse_categorical_crossentropy",
                "severity":    "sparse_categorical_crossentropy",
            },
            loss_weights={"damage_type": 1.0, "severity": 0.6},
            metrics={
                "damage_type": ["accuracy"],
                "severity":    ["accuracy"],
            },
        )

        model.fit(
            train_ds,
            validation_data=val_ds,
            epochs=args.epochs2,
            callbacks=make_callbacks(keras_path),
            verbose=1,
        )

    # ── Evaluate ──────────────────────────────────────────────────────────────
    print(f"\n[Evaluate] Loading best model from {keras_path}")
    model = keras.models.load_model(keras_path)
    results = model.evaluate(test_ds, verbose=1)
    names   = model.metrics_names
    print(f"\n  Available metrics: {dict(zip(names, [round(float(r),4) for r in results]))}")

    # Find accuracy values by partial name match (robust across Keras versions)
    dt_acc = next((float(results[i]) for i, n in enumerate(names)
                   if "damage_type" in n and "acc" in n), None)
    sv_acc = next((float(results[i]) for i, n in enumerate(names)
                   if "severity" in n and "acc" in n), None)

    if dt_acc is not None:
        print(f"  damage_type accuracy : {dt_acc:.4f}")
    if sv_acc is not None:
        print(f"  severity accuracy    : {sv_acc:.4f}")

    _print_classification_report(model, test_ds)

    # ── Save metadata ─────────────────────────────────────────────────────────
    meta = {
        "damage_types":              DAMAGE_TYPES,
        "severity_levels":           SEVERITY_LEVELS,
        "img_size":                  [224, 224],
        "test_damage_type_accuracy": round(dt_acc, 4) if dt_acc else None,
        "test_severity_accuracy":    round(sv_acc, 4) if sv_acc else None,
    }
    Path(meta_path).write_text(json.dumps(meta, indent=2))

    print(f"\n{'='*60}")
    print(f"  Training complete!")
    print(f"  Model : {keras_path}")
    print(f"  Meta  : {meta_path}")
    print(f"{'='*60}\n")


def _print_classification_report(model, test_ds) -> None:
    from sklearn.metrics import classification_report
    y_true_dt, y_pred_dt = [], []
    y_true_sv, y_pred_sv = [], []

    for imgs, labels in test_ds:
        preds = model.predict(imgs, verbose=0)
        y_pred_dt.extend(np.argmax(preds["damage_type"], axis=1))
        y_pred_sv.extend(np.argmax(preds["severity"],    axis=1))
        y_true_dt.extend(labels["damage_type"].numpy())
        y_true_sv.extend(labels["severity"].numpy())

    print("\n-- Damage Type Report --")
    print(classification_report(y_true_dt, y_pred_dt,
                                target_names=DAMAGE_TYPES, zero_division=0))
    print("-- Severity Report --")
    print(classification_report(y_true_sv, y_pred_sv,
                                target_names=SEVERITY_LEVELS, zero_division=0))


# ── CLI ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data_root",       default="./data")
    parser.add_argument("--output",          default="./models/road_damage.keras")
    parser.add_argument("--batch_size",      type=int,   default=32)
    parser.add_argument("--epochs1",         type=int,   default=20)
    parser.add_argument("--epochs2",         type=int,   default=10)
    parser.add_argument("--lr_phase1",       type=float, default=1e-3)
    parser.add_argument("--lr_phase2",       type=float, default=1e-5)
    parser.add_argument("--unfreeze_layers", type=int,   default=30)
    parser.add_argument("--max_per_class",   type=int,   default=3000)
    parser.add_argument("--countries",       default=None)
    train(parser.parse_args())
