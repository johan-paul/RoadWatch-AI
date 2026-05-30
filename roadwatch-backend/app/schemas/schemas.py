import uuid
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, field_validator
import re

from app.models.models import (
    UserRole, DamageType, SeverityLevel,
    ComplaintStatus, VerificationResponse, RepairStatus
)


# ── Helpers ───────────────────────────────────────────────────────────────────

def validate_phone(v: str) -> str:
    cleaned = re.sub(r"[\s\-\(\)]", "", v)
    if not re.match(r"^\+?[1-9]\d{7,14}$", cleaned):
        raise ValueError("Invalid phone number format. Use international format e.g. +919876543210")
    return cleaned


# ── Auth ──────────────────────────────────────────────────────────────────────

class PhoneCheckRequest(BaseModel):
    phone_number: str

    @field_validator("phone_number")
    @classmethod
    def check_phone(cls, v):
        return validate_phone(v)


class PhoneCheckResponse(BaseModel):
    phone_number: str
    status: str   # "citizen" | "officer" | "new" | "suspended"
    role: Optional[UserRole] = None


class CitizenRegisterRequest(BaseModel):
    phone_number: str
    name: str = Field(..., min_length=2, max_length=100)
    firebase_id_token: str

    @field_validator("phone_number")
    @classmethod
    def check_phone(cls, v):
        return validate_phone(v)

    @field_validator("name")
    @classmethod
    def clean_name(cls, v):
        return v.strip()


class FirebaseLoginRequest(BaseModel):
    """Existing users log in by sending their Firebase Phone ID token."""
    firebase_id_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    role: UserRole
    user_id: str
    name: str


class RefreshRequest(BaseModel):
    refresh_token: str


# ── User ──────────────────────────────────────────────────────────────────────

class UserOut(BaseModel):
    id: uuid.UUID
    phone_number: str
    name: str
    role: UserRole
    trust_score: int
    is_suspended: bool
    avatar_url: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class UserProfileUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    avatar_url: Optional[str] = None


# ── Officer ───────────────────────────────────────────────────────────────────

class OfficerCreate(BaseModel):
    phone_number: str
    name: str = Field(..., min_length=2, max_length=100)
    employee_id: Optional[str] = None
    department: Optional[str] = None
    ward_number: Optional[str] = None
    area_name: Optional[str] = None
    zone: Optional[str] = None
    jurisdiction_geojson: Optional[dict] = None

    @field_validator("phone_number")
    @classmethod
    def check_phone(cls, v):
        return validate_phone(v)


class OfficerUpdate(BaseModel):
    name: Optional[str] = None
    employee_id: Optional[str] = None
    department: Optional[str] = None
    ward_number: Optional[str] = None
    area_name: Optional[str] = None
    zone: Optional[str] = None
    jurisdiction_geojson: Optional[dict] = None


class OfficerOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    employee_id: Optional[str]
    department: Optional[str]
    ward_number: Optional[str]
    area_name: Optional[str]
    zone: Optional[str]
    jurisdiction_geojson: Optional[dict]
    workload_count: int
    user: UserOut

    model_config = {"from_attributes": True}


# ── Complaint ─────────────────────────────────────────────────────────────────

class ComplaintCreate(BaseModel):
    location_lat: float = Field(..., ge=-90, le=90)
    location_lng: float = Field(..., ge=-180, le=180)
    location_address: Optional[str] = None
    description: Optional[str] = Field(None, max_length=1000)


class ComplaintOut(BaseModel):
    id: uuid.UUID
    citizen_id: uuid.UUID
    location_lat: float
    location_lng: float
    location_address: Optional[str]
    image_url: str
    video_url: Optional[str]
    description: Optional[str]
    damage_type: Optional[DamageType]
    severity: Optional[SeverityLevel]
    ai_confidence_score: Optional[float]
    ai_risk_score: Optional[float]
    status: ComplaintStatus
    assigned_officer_id: Optional[uuid.UUID]
    assigned_officer_name: Optional[str] = None       # denormalised for mobile
    assigned_officer_phone: Optional[str] = None      # denormalised for mobile
    assigned_at: Optional[datetime] = None
    is_duplicate: bool
    duplicate_of: Optional[uuid.UUID]
    verified_confidence_score: Optional[float]
    confirmation_count: int
    rejection_count: int
    resolution_notes: Optional[str]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_with_officer(cls, complaint, officer_user=None) -> "ComplaintOut":
        """Build ComplaintOut and populate officer fields from the related User."""
        obj = cls.model_validate(complaint)
        if officer_user:
            obj.assigned_officer_name  = officer_user.name
            obj.assigned_officer_phone = officer_user.phone_number
        return obj


class ComplaintListOut(BaseModel):
    items: List[ComplaintOut]
    total: int
    page: int
    page_size: int


class ComplaintStatusUpdate(BaseModel):
    status: ComplaintStatus
    resolution_notes: Optional[str] = None


class ComplaintReassign(BaseModel):
    officer_id: uuid.UUID
    reason: Optional[str] = None


# ── Verification ──────────────────────────────────────────────────────────────

class VerificationCreate(BaseModel):
    response: VerificationResponse
    notes: Optional[str] = Field(None, max_length=500)


class VerificationOut(BaseModel):
    id: uuid.UUID
    complaint_id: uuid.UUID
    verifier_id: uuid.UUID
    response: VerificationResponse
    evidence_url: Optional[str]
    notes: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Repair Log ────────────────────────────────────────────────────────────────

class RepairLogCreate(BaseModel):
    notes: Optional[str] = Field(None, max_length=1000)


class RepairLogUpdate(BaseModel):
    status: RepairStatus
    notes: Optional[str] = None


class RepairLogOut(BaseModel):
    id: uuid.UUID
    complaint_id: uuid.UUID
    officer_id: uuid.UUID
    before_image_url: Optional[str]
    after_image_url: Optional[str]
    status: RepairStatus
    ai_verification_score: Optional[float]
    ai_verified: Optional[bool]
    notes: Optional[str]
    completed_at: Optional[datetime]
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Admin ─────────────────────────────────────────────────────────────────────

class AdminLoginRequest(BaseModel):
    phone_number: str
    admin_secret: str


class SuspendRequest(BaseModel):
    reason: Optional[str] = Field(None, max_length=500)


class AdminStatsOut(BaseModel):
    total_complaints: int
    pending_complaints: int
    resolved_complaints: int
    total_citizens: int
    total_officers: int
    high_severity_open: int
    avg_resolution_hours: Optional[float]


# ── Heatmap ───────────────────────────────────────────────────────────────────

class HeatmapPoint(BaseModel):
    lat: float
    lng: float
    weight: float
    complaint_id: str
    status: ComplaintStatus


class HeatmapResponse(BaseModel):
    points: List[HeatmapPoint]
    total: int


# ── Upload ────────────────────────────────────────────────────────────────────

class UploadResponse(BaseModel):
    url: str
    path: str
