"""
Road Damage Classifier — TensorFlow/Keras multi-output EfficientNetB0.

Architecture:
  Input (224, 224, 3)  — float32 in [0, 1]
    └─ Rescaling(255.0)  — converts to [0, 255] for EfficientNet
       └─ EfficientNetB0 backbone (ImageNet weights, frozen in phase 1)
          └─ GlobalAveragePooling2D
             └─ BatchNorm → Dropout(0.35)
                ├─ Dense(256) → BN → Dropout → Dense(5, softmax)  [damage_type]
                └─ Dense(128) → BN → Dropout → Dense(3, softmax)  [severity]

Output:
  {
    "damage_type": (batch, 5)  softmax probabilities
    "severity":    (batch, 3)  softmax probabilities
  }

Saved as:  models/road_damage.keras
"""

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

IMG_SIZE   = (224, 224)
N_DAMAGE   = 5   # pothole, crack, waterlogging, damaged_road, other
N_SEVERITY = 3   # low, medium, high


def build_model(
    freeze_backbone: bool = True,
    dropout_rate: float = 0.35,
    learning_rate: float = 1e-3,
) -> keras.Model:
    inputs = keras.Input(shape=(*IMG_SIZE, 3), name="image")

    # EfficientNet expects pixel values in [0, 255]
    x = layers.Rescaling(255.0)(inputs)
    backbone = keras.applications.EfficientNetB0(
        include_top=False,
        weights="imagenet",
        input_tensor=x,
    )
    backbone.trainable = not freeze_backbone

    # ── Shared feature vector ─────────────────────────────────────────────────
    features = layers.GlobalAveragePooling2D(name="gap")(backbone.output)
    features = layers.BatchNormalization(name="bn_shared")(features)
    features = layers.Dropout(dropout_rate, name="drop_shared")(features)

    # ── Head 1: Damage Type ───────────────────────────────────────────────────
    dt = layers.Dense(256, activation="relu", name="dt_dense")(features)
    dt = layers.BatchNormalization(name="dt_bn")(dt)
    dt = layers.Dropout(0.25, name="dt_drop")(dt)
    damage_type_out = layers.Dense(N_DAMAGE, activation="softmax",
                                   name="damage_type")(dt)

    # ── Head 2: Severity ──────────────────────────────────────────────────────
    sv = layers.Dense(128, activation="relu", name="sv_dense")(features)
    sv = layers.BatchNormalization(name="sv_bn")(sv)
    sv = layers.Dropout(0.20, name="sv_drop")(sv)
    severity_out = layers.Dense(N_SEVERITY, activation="softmax",
                                name="severity")(sv)

    model = keras.Model(
        inputs=inputs,
        outputs={"damage_type": damage_type_out, "severity": severity_out},
        name="RoadDamageNet",
    )
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=learning_rate),
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
    return model


def unfreeze_top_layers(model: keras.Model, n_layers: int = 30) -> None:
    """Unfreeze the last N backbone layers for phase-2 fine-tuning."""
    for layer in model.layers[-n_layers:]:
        if not isinstance(layer, layers.BatchNormalization):
            layer.trainable = True
    trainable = sum(
        tf.size(w).numpy() for w in model.trainable_weights
    )
    print(f"[model] Unfroze last {n_layers} layers — trainable params: {trainable:,}")
