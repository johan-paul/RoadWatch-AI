---
name: project-roadwatch
description: RoadWatch AI platform — civic road monitoring with Flutter app and FastAPI/Supabase backend
metadata:
  type: project
---

RoadWatch AI — civic road hazard reporting and monitoring platform.

**Why:** Smart city infrastructure management with AI damage detection, community verification, and officer assignment.

**How to apply:** This is the primary project context for this session. Backend is FastAPI + Supabase (PostgreSQL). Mobile app is Flutter (single app for citizens and officers).

## Key design decisions
- Single Flutter app for citizens and officers (role-based routing on login)
- OTP-only login via Firebase Phone Auth (no email/password)
- Citizens self-register; officer accounts created only by admin
- Admin dashboard is a separate web app (React) — not the Flutter app

## Backend location
`C:\Users\Johan Paul\Desktop\road\roadwatch-backend\`

The original files were scattered in misnamed folders ("audit log", "logout", "RepairLog, AuditLog").
Fixed structure places everything in `app/` with proper subdirectories.

## Flutter app location
`C:\Users\Johan Paul\Desktop\road\roadwatch_app\`

## Auth flow
1. Enter phone → backend `/auth/check-phone` → returns status (new/citizen/officer/suspended)
2. new → name entry → Firebase OTP → `/auth/register`
3. citizen/officer → Firebase OTP → `/auth/login`
4. Response contains role → navigate to citizen or officer screens

## Backend missing files (created in this session)
- app/config.py
- app/middleware/auth.py (JWT dependency injector)
- All __init__.py files
- All routers (moved from wrong folders)
- All services (moved from wrong folders)
- app/schemas/schemas.py (moved from wrong folder)
