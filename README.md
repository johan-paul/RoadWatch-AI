# RoadWatch AI 🛣️

**AI-powered road hazard monitoring and transparent civic governance platform.**

A complete production-ready system: citizens report road damage with photos, an AI model classifies the damage and estimates risk, the system auto-assigns the complaint to the right field officer, the officer repairs it and uploads an after-photo, and a second AI step verifies the repair. Admins monitor everything from a real-time dashboard.

---

## 🏛️ Architecture

```
┌──────────────────────┐    ┌──────────────────────┐    ┌──────────────────────┐
│  Mobile App          │    │  FastAPI Backend     │    │  Admin Dashboard     │
│  (Flutter)           │◄──►│  (Python)            │◄──►│  (React + Vite)      │
│  Citizens + Officers │    │  AI / DB / FCM       │    │  Government admins   │
└──────────────────────┘    └──────────┬───────────┘    └──────────────────────┘
                                       │
                ┌──────────────────────┼──────────────────────┐
                ▼                      ▼                      ▼
        ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
        │  Supabase    │      │  Firebase    │      │  TensorFlow  │
        │  Postgres    │      │  Auth + FCM  │      │  Keras model │
        │  + Storage   │      │              │      │ (EfficientNet│
        └──────────────┘      └──────────────┘      │     B0)      │
                                                    └──────────────┘
```

## 📦 Repository Layout

| Folder | Stack | Purpose |
|--------|-------|---------|
| `roadwatch-backend/` | FastAPI + SQLAlchemy + asyncpg + TensorFlow | REST API, AI inference, FCM, business logic |
| `roadwatch_app/` | Flutter + Riverpod + go_router | Single mobile app — role-routed for citizens & officers |
| `roadwatch-admin/` | React + Vite + TypeScript + Tailwind | Government admin web dashboard |
| `roadwatch-backend/ai/` | TensorFlow / Keras | Training pipeline (dataset loader, model, train, evaluate) |
| `roadwatch-backend/models/road_damage.keras` | 31 MB Keras file | Pre-trained EfficientNetB0 multi-head classifier — ships with the repo |

---

## ✨ Features

### Citizens
- OTP login (Firebase Phone Auth)
- Report road damage with photo + GPS + auto-address + description
- AI instantly classifies damage type, severity, confidence, and risk score
- Real-time complaint tracking with animated 4-step timeline
- View assigned officer details
- Community verification (👍/👎) on nearby complaints with optional evidence
- Heatmap of nearby hazards
- Push notifications for every status change

### Officers
- Same OTP login, role-based UI
- Dashboard with assigned/in-progress/resolved/average-resolution stats
- "Navigate to Site" → opens Google Maps with driving directions
- Start Repair → AI verifies before/after photos via SSIM
- Repair verification result sheet (pass/fail with reason)
- Emergency escalation push notifications

### Admin Dashboard
- Officer CRUD + jurisdiction polygons + ward/zone management
- Complaint monitoring + manual reassignment + emergency escalation
- **Priority Queue** ranked by `severity × AI risk × density × recency`
- **Budget Dashboard** with estimated INR costs by damage type + monthly trend
- Heatmap, audit logs, citizen suspension, analytics

### AI System
- **Custom EfficientNetB0** trained on RDD2022 (~26K images, India + Japan + Czech + Norway + China + USA)
- Dual-head: `damage_type` (5 classes) + `severity` (3 classes)
- Risk scoring: `type_risk × severity_weight × confidence + density_bonus`
- Haversine-based duplicate detection (75 m / 30 days)
- SSIM repair verification (before/after photo comparison)
- Graceful degradation when model is unavailable

### Smart Systems
- 3-tier officer auto-assignment: jurisdiction polygon → zone → least-loaded
- Trust-score gated submissions + community-verified confidence
- Server-side rate limits + role-based access control
- Token rotation + refresh-token revocation

---

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Node.js 18+
- Flutter 3.13+ (Dart 3.2+)
- A Supabase project (Postgres + Storage)
- A Firebase project (Phone Auth + FCM + Service Account JSON)

### 1. Backend
```bash
cd roadwatch-backend
python -m venv venv
venv\Scripts\activate                # Windows
# source venv/bin/activate           # macOS/Linux
pip install -r requirements.txt

cp .env.example .env                 # then fill in real values
# Replace firebase-credentials.example.json with the real one from Firebase
# Renamed to: firebase-credentials.json

# Create the admin user
python create_admin.py

# Run
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Visit `http://localhost:8000/docs` for the OpenAPI spec.

### 2. Admin Dashboard
```bash
cd roadwatch-admin
npm install
npm run dev                          # http://localhost:5173
```

### 3. Mobile App
```bash
cd roadwatch_app
flutter pub get

# Edit lib/core/constants/api_constants.dart and set baseUrl to your LAN IP
# Add android/app/google-services.json from Firebase Console
# Add ios/Runner/GoogleService-Info.plist from Firebase Console

flutter run
```

### 4. (Optional) Re-train the AI model
The repository ships with a trained model at `roadwatch-backend/models/road_damage.keras`. To retrain on your own data:

```bash
# Download RDD2022 from https://figshare.com/articles/dataset/RDD2022/21431547
# Extract to roadwatch-backend/data/RDD_SPLIT/{train,val,test}/{images,labels}

cd roadwatch-backend
python -m ai.train --data_root ./data --output ./models/road_damage.keras --epochs1 20 --epochs2 10
```

See `roadwatch-backend/ai/README.md` for full training instructions (local + Google Colab).

---

## 🔒 Security Notes
- `.env` and `firebase-credentials.json` are gitignored — **never commit them**.
- The Supabase service-role key bypasses Row-Level Security; treat it like a root password.
- The admin dashboard login uses `ADMIN_SECRET` + admin phone — do not deploy with the example value.
- All app endpoints require a Bearer JWT; admin endpoints additionally require `role=admin`.

## 📜 License
This project is submitted as-is for evaluation. All rights reserved by the author.

## 🙏 Credits
- **RDD2022** dataset: Sekilab / Tohoku University
- **EfficientNetB0**: Google / Keras Applications
- **OpenStreetMap** tiles for maps
- **Firebase / Supabase** for auth & infra
