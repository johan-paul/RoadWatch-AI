import uuid
import enum
from datetime import datetime
from sqlalchemy import (
    String, Boolean, Integer, Float, Text, DateTime,
    ForeignKey, JSON, Enum as SAEnum, func
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


# ── Enums ─────────────────────────────────────────────────────────────────────

class UserRole(str, enum.Enum):
    citizen = "citizen"
    officer = "officer"
    admin   = "admin"


class DamageType(str, enum.Enum):
    pothole     = "pothole"
    crack       = "crack"
    waterlogging = "waterlogging"
    damaged_road = "damaged_road"
    other       = "other"


class SeverityLevel(str, enum.Enum):
    low    = "low"
    medium = "medium"
    high   = "high"


class ComplaintStatus(str, enum.Enum):
    pending     = "pending"
    assigned    = "assigned"
    in_progress = "in_progress"
    resolved    = "resolved"
    rejected    = "rejected"
    duplicate   = "duplicate"


class VerificationResponse(str, enum.Enum):
    confirmed = "confirmed"
    rejected  = "rejected"


class RepairStatus(str, enum.Enum):
    pending    = "pending"
    in_progress = "in_progress"
    completed  = "completed"
    failed     = "failed"


# ── User ──────────────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    phone_number: Mapped[str] = mapped_column(String(20), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    role: Mapped[UserRole] = mapped_column(SAEnum(UserRole), nullable=False)
    trust_score: Mapped[int] = mapped_column(Integer, default=100, nullable=False)
    is_suspended: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    suspension_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    fcm_token:  Mapped[str | None] = mapped_column(Text, nullable=True)   # Firebase Cloud Messaging device token

    # For officers — which admin created this account
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    officer_profile: Mapped["Officer"] = relationship("Officer", back_populates="user", uselist=False)
    complaints: Mapped[list["Complaint"]] = relationship(
        "Complaint", foreign_keys="Complaint.citizen_id", back_populates="citizen"
    )
    assigned_complaints: Mapped[list["Complaint"]] = relationship(
        "Complaint", foreign_keys="Complaint.assigned_officer_id", back_populates="assigned_officer"
    )
    verifications: Mapped[list["Verification"]] = relationship("Verification", back_populates="verifier")
    audit_logs: Mapped[list["AuditLog"]] = relationship("AuditLog", foreign_keys="AuditLog.actor_id", back_populates="actor")


# ── Officer ───────────────────────────────────────────────────────────────────

class Officer(Base):
    __tablename__ = "officers"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    employee_id: Mapped[str | None] = mapped_column(String(50), nullable=True)
    department: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # GeoJSON polygon defining this officer's jurisdiction
    jurisdiction_geojson: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    # Location / jurisdiction fields — used to filter complaints shown to the officer
    ward_number: Mapped[str | None] = mapped_column(String(50),  nullable=True)
    area_name:   Mapped[str | None] = mapped_column(String(100), nullable=True)
    zone:        Mapped[str | None] = mapped_column(String(50),  nullable=True)

    # Denormalized count for fast workload queries
    workload_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship("User", back_populates="officer_profile")


# ── Complaint ─────────────────────────────────────────────────────────────────

class Complaint(Base):
    __tablename__ = "complaints"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    citizen_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )

    # Location
    location_lat: Mapped[float] = mapped_column(Float, nullable=False)
    location_lng: Mapped[float] = mapped_column(Float, nullable=False)
    location_address: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Media
    image_url: Mapped[str] = mapped_column(Text, nullable=False)
    video_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Description
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    # AI analysis
    damage_type: Mapped[DamageType | None] = mapped_column(SAEnum(DamageType), nullable=True)
    severity: Mapped[SeverityLevel | None] = mapped_column(SAEnum(SeverityLevel), nullable=True)
    ai_confidence_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    ai_risk_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    ai_analysis_raw: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    # Status & assignment
    status: Mapped[ComplaintStatus] = mapped_column(
        SAEnum(ComplaintStatus), default=ComplaintStatus.pending, nullable=False, index=True
    )
    assigned_officer_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True
    )
    assigned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Duplicate detection
    is_duplicate: Mapped[bool] = mapped_column(Boolean, default=False)
    duplicate_of: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)

    # Community verification
    verified_confidence_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    confirmation_count: Mapped[int] = mapped_column(Integer, default=0)
    rejection_count: Mapped[int] = mapped_column(Integer, default=0)

    # Admin/officer notes
    resolution_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    citizen: Mapped["User"] = relationship("User", foreign_keys=[citizen_id], back_populates="complaints")
    assigned_officer: Mapped["User"] = relationship(
        "User", foreign_keys=[assigned_officer_id], back_populates="assigned_complaints"
    )
    verifications: Mapped[list["Verification"]] = relationship("Verification", back_populates="complaint")
    repair_log: Mapped["RepairLog"] = relationship("RepairLog", back_populates="complaint", uselist=False)


# ── Verification ──────────────────────────────────────────────────────────────

class Verification(Base):
    __tablename__ = "verifications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    complaint_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("complaints.id", ondelete="CASCADE"), nullable=False, index=True
    )
    verifier_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    response: Mapped[VerificationResponse] = mapped_column(SAEnum(VerificationResponse), nullable=False)
    evidence_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    complaint: Mapped["Complaint"] = relationship("Complaint", back_populates="verifications")
    verifier: Mapped["User"] = relationship("User", back_populates="verifications")


# ── Repair Log ────────────────────────────────────────────────────────────────

class RepairLog(Base):
    __tablename__ = "repair_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    complaint_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("complaints.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    officer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    before_image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    after_image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[RepairStatus] = mapped_column(
        SAEnum(RepairStatus), default=RepairStatus.pending, nullable=False
    )
    ai_verification_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    ai_verified: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    complaint: Mapped["Complaint"] = relationship("Complaint", back_populates="repair_log")


# ── Audit Log ─────────────────────────────────────────────────────────────────

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    actor_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    action: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    target_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    target_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    extra_data: Mapped[dict | None] = mapped_column("metadata", JSON, nullable=True)
    ip_address: Mapped[str | None] = mapped_column(String(50), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )

    actor: Mapped["User"] = relationship("User", foreign_keys=[actor_id], back_populates="audit_logs")


# ── Refresh Token ─────────────────────────────────────────────────────────────

class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    token_hash: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
