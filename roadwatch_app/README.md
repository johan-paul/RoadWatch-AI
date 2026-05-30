# RoadWatch AI — Flutter App

AI-powered civic road monitoring platform. Citizens report road hazards; officers manage and resolve them. Single app, role-based UX.

---

## Architecture

```
lib/
├── main.dart                        # Firebase init, ProviderScope, orientation lock
├── app.dart                         # GoRouter + Material 3 theme + Shell widgets
├── core/
│   ├── constants/
│   │   ├── app_colors.dart          # Design tokens
│   │   └── api_constants.dart       # Base URL + endpoint paths
│   ├── models/
│   │   └── user_model.dart
│   ├── network/
│   │   └── api_client.dart          # Dio + auto token-refresh interceptor
│   ├── storage/
│   │   └── secure_storage.dart      # flutter_secure_storage wrapper
│   └── utils/
│       └── formatters.dart          # Date/label helpers
├── features/
│   ├── auth/                        # Phone entry → OTP → JWT login/register
│   ├── citizen/                     # Home, Report, My Reports, Map, Profile
│   └── officer/                     # Dashboard, Assignments, Map, Profile
└── shared/
    └── widgets/                     # CustomButton, ComplaintCard, Badges, etc.
```

---

## Prerequisites

| Tool | Version |
|---|---|
| Flutter | ≥ 3.22 |
| Dart | ≥ 3.4 |
| Android Studio / Xcode | Latest stable |
| Firebase project | Phone Auth enabled |
| RoadWatch backend | Running (see backend README) |

---

## 1. Generate Flutter Platform Files

The `lib/` directory and `pubspec.yaml` are pre-written. Run this **once** inside the project folder to generate the Android/iOS scaffolding:

```bash
cd roadwatch_app
flutter create --org com.roadwatch --project-name roadwatch_app .
```

> Flutter will generate Android/iOS/web/desktop shells without overwriting files that already exist (`lib/`, `pubspec.yaml`, and the `android/app/src/main/AndroidManifest.xml` we pre-configured).

---

## 2. Firebase Setup

### 2a. Create a Firebase project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create project → **RoadWatch AI**
3. Enable **Authentication → Phone** sign-in method

### 2b. Register Android app
1. Package name: `com.roadwatch.roadwatch_app`
2. Download **`google-services.json`**
3. Place it at:
   ```
   roadwatch_app/android/app/google-services.json
   ```

### 2c. Register iOS app (if needed)
1. Bundle ID: `com.roadwatch.roadwatchApp`
2. Download **`GoogleService-Info.plist`**
3. Place it at:
   ```
   roadwatch_app/ios/Runner/GoogleService-Info.plist
   ```

### 2d. Update `android/app/build.gradle`

After `flutter create .`, open `android/app/build.gradle` and ensure:

```gradle
apply plugin: 'com.google.gms.google-services'
```

And in `android/build.gradle` (project-level):

```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.2'
}
```

---

## 3. Backend Configuration

By default the app connects to `http://10.0.2.2:8000/api/v1` (Android emulator → host localhost).

| Target | URL to set in `lib/core/constants/api_constants.dart` |
|---|---|
| Android emulator | `http://10.0.2.2:8000/api/v1` (default) |
| iOS simulator | `http://localhost:8000/api/v1` |
| Physical device (LAN) | `http://192.168.x.x:8000/api/v1` |
| Production | `https://api.yourserver.com/api/v1` |

### Start the backend

```bash
cd roadwatch-backend
pip install -r requirements.txt
cp .env.example .env   # fill in Supabase URL, keys, Firebase project ID
uvicorn app.main:app --reload --port 8000
```

---

## 4. Install Flutter Dependencies

```bash
flutter pub get
```

---

## 5. Run the App

```bash
# Android emulator (preferred for development)
flutter run -d android

# iOS simulator
flutter run -d ios

# Release build
flutter build apk --release
```

---

## Key Permissions (AndroidManifest.xml)

| Permission | Purpose |
|---|---|
| `INTERNET` | API calls, tile map, Firebase |
| `ACCESS_FINE_LOCATION` | GPS tagging of complaints |
| `CAMERA` | Take photos of road damage |
| `READ_MEDIA_IMAGES` | Pick from gallery (Android 13+) |
| `READ_EXTERNAL_STORAGE` | Pick from gallery (Android ≤ 12) |

---

## Authentication Flow

```
Phone Entry Screen
      │
      ├─ New number    → Register Screen (name only) → OTP Screen → Citizen Home
      ├─ Citizen phone → OTP Screen → Citizen Home
      ├─ Officer phone → OTP Screen → Officer Dashboard
      └─ Suspended     → Error dialog (cannot proceed)
```

- Firebase verifies the OTP on-device and returns an **ID token**
- The ID token is sent to the backend (`POST /auth/login` or `/auth/register`)
- Backend validates with Firebase Admin SDK, issues short-lived **JWT access token** (15 min) + **refresh token** (7 days)
- Tokens are stored in `flutter_secure_storage` (encrypted on both Android & iOS)
- Dio interceptor auto-refreshes on 401 without user intervention

---

## Role-Based Routing

| JWT Role | Default route | Blocked from |
|---|---|---|
| `citizen` | `/citizen/home` | `/officer/*` |
| `officer` | `/officer/home` | `/citizen/*` |

Officers can only be created by an **admin** via the web dashboard (`POST /admin/officers`). Citizens self-register via the app.

---

## Trust Score System (Citizens)

- New citizens start at **100**
- False reports (rejected by community) **lower** the score
- Confirmed reports **raise** the score  
- Minimum score to submit: **20**
- Displayed visually on the Profile screen with colour coding:
  - ≥ 80 → Green (Excellent Reporter)
  - ≥ 50 → Amber (Good Reporter)
  - < 50 → Red (Needs Improvement)

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `MissingPluginException` for geolocator | Run `flutter clean && flutter pub get` |
| Firebase Phone Auth not working | Confirm SHA-1 fingerprint is added in Firebase console |
| Map tiles not loading on device | Check `network_security_config.xml` and internet permission |
| `401 Unauthorized` on all requests | Check backend is running; verify `baseUrl` in `api_constants.dart` |
| OTP never arrives | Firebase test numbers: add them in Firebase console Authentication → Phone → Test phone numbers |
