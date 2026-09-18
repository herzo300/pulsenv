"""SQLAlchemy models for admin runtime metrics and camera catalog."""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    DateTime,
    Float,
    Integer,
    String,
    Text,
)

from services.data_layer.database import Base


def _utcnow() -> datetime:
    return datetime.now(UTC)


# Module-level constants for models
ADMIN_SESSION_ROW_ID = "global"


class AdminRuntimeStats(Base):
    __tablename__ = "admin_runtime_stats"

    id = Column(String(32), primary_key=True, default=ADMIN_SESSION_ROW_ID)
    started_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    last_activity_at = Column(DateTime(timezone=True), nullable=True)
    total_requests = Column(BigInteger, nullable=False, default=0)
    total_heartbeats = Column(BigInteger, nullable=False, default=0)
    total_request_bytes = Column(BigInteger, nullable=False, default=0)
    total_response_bytes = Column(BigInteger, nullable=False, default=0)
    peak_active_devices = Column(Integer, nullable=False, default=0)


class AdminRuntimeDevice(Base):
    __tablename__ = "admin_runtime_devices"

    device_id = Column(String(128), primary_key=True)
    platform = Column(String(32), nullable=False, default="unknown")
    app_version = Column(String(32), nullable=False, default="unknown")
    current_screen = Column(String(64), nullable=False, default="unknown")
    first_seen_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    last_seen_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    last_ip = Column(String(64), nullable=False, default="unknown")
    heartbeat_count = Column(BigInteger, nullable=False, default=0)
    request_count = Column(BigInteger, nullable=False, default=0)
    total_request_bytes = Column(BigInteger, nullable=False, default=0)
    total_response_bytes = Column(BigInteger, nullable=False, default=0)


class AdminRequestEvent(Base):
    __tablename__ = "admin_request_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(String(128), nullable=False, index=True)
    route = Column(String(255), nullable=False, index=True)
    happened_at = Column(
        DateTime(timezone=True), nullable=False, default=_utcnow, index=True
    )
    request_bytes = Column(BigInteger, nullable=False, default=0)
    response_bytes = Column(BigInteger, nullable=False, default=0)


class AdminHeartbeatEvent(Base):
    __tablename__ = "admin_heartbeat_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(String(128), nullable=False, index=True)
    platform = Column(String(32), nullable=False, default="unknown")
    app_version = Column(String(32), nullable=False, default="unknown")
    screen = Column(String(64), nullable=False, default="unknown")
    ip = Column(String(64), nullable=False, default="unknown")
    happened_at = Column(
        DateTime(timezone=True), nullable=False, default=_utcnow, index=True
    )


class AdminAccessPolicy(Base):
    __tablename__ = "admin_access_policies"

    device_id = Column(String(128), primary_key=True)
    map_access = Column(Boolean, nullable=False, default=True)
    camera_access = Column(Boolean, nullable=False, default=True)
    free_access = Column(Boolean, nullable=False, default=True)
    note = Column(Text, nullable=False, default="")
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)


class AdminSessionLock(Base):
    __tablename__ = "admin_session_locks"

    id = Column(String(32), primary_key=True, default=ADMIN_SESSION_ROW_ID)
    device_id_hash = Column(String(64), nullable=True)
    session_token_hash = Column(String(64), nullable=True)
    session_expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    last_seen_at = Column(DateTime(timezone=True), nullable=True)


class AdminCameraCatalog(Base):
    __tablename__ = "admin_camera_catalog"

    camera_id = Column(String(64), primary_key=True)
    name = Column(String(255), nullable=False, default="Камера")
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    stream_url = Column(Text, nullable=False)
    streamable = Column(Boolean, nullable=False, default=True)
    hidden_by_admin = Column(Boolean, nullable=False, default=False)
    hidden_due_to_offline = Column(Boolean, nullable=False, default=False)
    probe_http_status = Column(Integer, nullable=True)
    probe_error = Column(Text, nullable=False, default="")
    last_checked_at = Column(DateTime(timezone=True), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
