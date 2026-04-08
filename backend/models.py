from datetime import UTC, datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from .database import Base


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    telegram_id = Column(Integer, unique=True, nullable=True)
    username = Column(String(100), unique=True, nullable=True)
    first_name = Column(String(100))
    last_name = Column(String(100))
    photo_url = Column(String(500), nullable=True)
    balance = Column(Integer, default=0)
    notify_new = Column(Integer, default=0)
    digest_subscription_until = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    reports = relationship("Report", back_populates="user")
    likes = relationship("Like", back_populates="user")
    comments = relationship("Comment", back_populates="user")


class Report(Base):
    __tablename__ = "reports"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    address = Column(String(300), nullable=True)
    category = Column(String(50), default="other")
    status = Column(String(20), default="pending")
    source = Column(String(50), default="mobile_app")
    telegram_message_id = Column(String(100), nullable=True)
    telegram_channel = Column(String(200), nullable=True)
    supporters = Column(Integer, default=0)
    supporters_notified = Column(Integer, default=0)
    likes_count = Column(Integer, default=0)
    dislikes_count = Column(Integer, default=0)
    uk_name = Column(String(300), nullable=True)
    uk_email = Column(String(200), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index("idx_category", "category"),
        Index("idx_status", "status"),
        Index("idx_created_at", "created_at"),
        Index("idx_user_id", "user_id"),
        Index("idx_lat_lng", "lat", "lng"),
    )

    user = relationship("User", back_populates="reports")
    likes = relationship("Like", back_populates="report", cascade="all, delete-orphan")
    comments = relationship(
        "Comment", back_populates="report", cascade="all, delete-orphan"
    )

    @property
    def comments_count(self):
        return len(self.comments) if self.comments else 0

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "lat": float(self.lat) if self.lat is not None else None,
            "lng": float(self.lng) if self.lng is not None else None,
            "latitude": float(self.lat) if self.lat is not None else None,
            "longitude": float(self.lng) if self.lng is not None else None,
            "address": self.address,
            "category": self.category,
            "status": self.status,
            "source": self.source,
            "user_id": self.user_id,
            "telegram_message_id": self.telegram_message_id,
            "telegram_channel": self.telegram_channel,
            "supporters": self.supporters or 0,
            "likes_count": self.likes_count or 0,
            "dislikes_count": self.dislikes_count or 0,
            "images": [],
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }


class Like(Base):
    __tablename__ = "likes"

    id = Column(Integer, primary_key=True)
    report_id = Column(Integer, ForeignKey("reports.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (UniqueConstraint("report_id", "user_id", name="unique_like"),)

    report = relationship("Report", back_populates="likes")
    user = relationship("User", back_populates="likes")


class Comment(Base):
    __tablename__ = "comments"

    id = Column(Integer, primary_key=True)
    report_id = Column(Integer, ForeignKey("reports.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    text = Column(Text, nullable=False)
    parent_id = Column(Integer, ForeignKey("comments.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    report = relationship("Report", back_populates="comments")
    user = relationship("User", back_populates="comments")
    parent = relationship("Comment", remote_side=[id], backref="replies")


class GeoSubscription(Base):
    """Push-подписка пользователя на район (уведомления через Telegram)."""
    __tablename__ = "geo_subscriptions"

    id = Column(Integer, primary_key=True)
    telegram_id = Column(Integer, nullable=False, index=True)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    radius_m = Column(Integer, default=500)
    label = Column(String(200), nullable=True)
    categories = Column(String(500), nullable=True)  # comma-separated, null = all
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("idx_geo_sub_tg", "telegram_id"),
        Index("idx_geo_sub_coords", "lat", "lng"),
    )


class UKRating(Base):
    """Рейтинг управляющей компании (агрегированная оценка)."""
    __tablename__ = "uk_ratings"

    id = Column(Integer, primary_key=True)
    uk_name = Column(String(300), nullable=False, unique=True)
    total_complaints = Column(Integer, default=0)
    resolved_complaints = Column(Integer, default=0)
    avg_response_days = Column(Float, nullable=True)
    citizen_score = Column(Float, default=0.0)  # 0-5 from user votes
    citizen_votes = Column(Integer, default=0)
    repeat_complaint_rate = Column(Float, default=0.0)
    overall_score = Column(Float, default=0.0)  # computed 0-100
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index("idx_uk_score", "overall_score"),
    )


class CameraAlert(Base):
    """Алерт от Camera Watchdog (автоанализ камер)."""
    __tablename__ = "camera_alerts"

    id = Column(Integer, primary_key=True)
    camera_name = Column(String(300), nullable=False)
    camera_lat = Column(Float, nullable=True)
    camera_lng = Column(Float, nullable=True)
    event_type = Column(String(100), nullable=False)  # dump, accident, flood, smoke, animals
    description = Column(Text, nullable=True)
    confidence = Column(Float, default=0.0)
    snapshot_url = Column(String(500), nullable=True)
    is_notified = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("idx_camera_alert_type", "event_type"),
        Index("idx_camera_alert_time", "created_at"),
    )


class VipSubscription(Base):
    """VIP-подписка на визуальный поиск по камерам."""
    __tablename__ = "vip_subscriptions"

    id = Column(Integer, primary_key=True)
    telegram_id = Column(Integer, nullable=False, unique=True)
    tier = Column(String(20), nullable=False, default="standard")  # standard | vip
    
    # AI Time Credits (in minutes)
    ai_minutes_total = Column(Integer, default=60) # 1 hour free by default
    ai_minutes_used = Column(Integer, default=0)
    
    # Active Tracking State
    is_track_active = Column(Boolean, default=False)
    track_started_at = Column(DateTime, nullable=True)
    last_deduction_at = Column(DateTime, nullable=True)
    
    searches_used = Column(Integer, default=0)
    searches_limit = Column(Integer, default=3)
    payment_id = Column(String(200), nullable=True)
    expires_at = Column(DateTime, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("idx_vip_tg", "telegram_id"),
        Index("idx_vip_expires", "expires_at"),
    )


class VisualSearchLog(Base):
    """Лог запросов визуального поиска по камерам."""
    __tablename__ = "visual_search_logs"

    id = Column(Integer, primary_key=True)
    telegram_id = Column(Integer, nullable=False)
    query_text = Column(Text, nullable=True)
    query_image_hash = Column(String(64), nullable=True)
    cameras_scanned = Column(Integer, default=0)
    matches_found = Column(Integer, default=0)
    results_json = Column(Text, nullable=True)  # JSON with matched cameras
    processing_time_sec = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("idx_vsearch_tg", "telegram_id"),
        Index("idx_vsearch_time", "created_at"),
    )


class TransactionRecord(Base):
    """Лог успешных транзакций для расчета призового фонда."""
    __tablename__ = "transaction_records"

    id = Column(Integer, primary_key=True)
    telegram_id = Column(Integer, nullable=False)
    amount = Column(Float, nullable=False)
    payment_id = Column(String(200), nullable=True, unique=True)
    plan_id = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("idx_tx_time", "created_at"),
        Index("idx_tx_tg", "telegram_id"),
    )


class AgentThread(Base):
    __tablename__ = "agent_threads"

    id = Column(Integer, primary_key=True)
    source = Column(String(80), nullable=False, default="manual")
    scope = Column(String(120), nullable=False, default="internal")
    task_type = Column(String(40), nullable=False, default="analyze")
    title = Column(String(200), nullable=True)
    status = Column(String(30), nullable=False, default="open")
    metadata_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    __table_args__ = (
        Index("idx_agent_thread_status", "status"),
        Index("idx_agent_thread_created", "created_at"),
    )

    messages = relationship(
        "AgentMessage",
        back_populates="thread",
        cascade="all, delete-orphan",
    )
    jobs = relationship(
        "AgentJob",
        back_populates="thread",
        cascade="all, delete-orphan",
    )
    facts = relationship(
        "AgentFact",
        back_populates="thread",
        cascade="all, delete-orphan",
    )
    tool_logs = relationship(
        "AgentToolLog",
        back_populates="thread",
        cascade="all, delete-orphan",
        foreign_keys="AgentToolLog.thread_id",
    )


class AgentMessage(Base):
    __tablename__ = "agent_messages"

    id = Column(Integer, primary_key=True)
    thread_id = Column(Integer, ForeignKey("agent_threads.id"), nullable=False)
    role = Column(String(30), nullable=False)
    content = Column(Text, nullable=True)
    structured_payload = Column(Text, nullable=True)
    model = Column(String(120), nullable=True)
    prompt_tokens = Column(Integer, nullable=True)
    completion_tokens = Column(Integer, nullable=True)
    total_tokens = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=_utcnow)

    __table_args__ = (
        Index("idx_agent_message_thread", "thread_id", "created_at"),
    )

    thread = relationship("AgentThread", back_populates="messages")


class AgentJob(Base):
    __tablename__ = "agent_jobs"

    id = Column(Integer, primary_key=True)
    thread_id = Column(Integer, ForeignKey("agent_threads.id"), nullable=False)
    job_type = Column(String(40), nullable=False)
    priority = Column(String(20), nullable=False, default="normal")
    status = Column(String(30), nullable=False, default="queued")
    context_json = Column(Text, nullable=True)
    result_summary = Column(Text, nullable=True)
    error_text = Column(Text, nullable=True)
    started_at = Column(DateTime, nullable=True)
    finished_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=_utcnow)

    __table_args__ = (
        Index("idx_agent_job_status", "status", "created_at"),
        Index("idx_agent_job_thread", "thread_id", "created_at"),
    )

    thread = relationship("AgentThread", back_populates="jobs")
    tool_logs = relationship(
        "AgentToolLog",
        back_populates="job",
        cascade="all, delete-orphan",
        foreign_keys="AgentToolLog.job_id",
    )


class AgentFact(Base):
    __tablename__ = "agent_facts"

    id = Column(Integer, primary_key=True)
    thread_id = Column(Integer, ForeignKey("agent_threads.id"), nullable=False)
    fact_key = Column(String(120), nullable=False)
    fact_value = Column(Text, nullable=False)
    confidence = Column(Float, default=0.0)
    expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=_utcnow)

    __table_args__ = (
        Index("idx_agent_fact_thread_key", "thread_id", "fact_key"),
    )

    thread = relationship("AgentThread", back_populates="facts")


class AgentToolLog(Base):
    __tablename__ = "agent_tool_logs"

    id = Column(Integer, primary_key=True)
    thread_id = Column(Integer, ForeignKey("agent_threads.id"), nullable=False)
    job_id = Column(Integer, ForeignKey("agent_jobs.id"), nullable=True)
    tool_name = Column(String(80), nullable=False)
    input_summary = Column(Text, nullable=True)
    output_summary = Column(Text, nullable=True)
    latency_ms = Column(Integer, nullable=True)
    success = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_utcnow)

    __table_args__ = (
        Index("idx_agent_tool_job", "job_id", "created_at"),
        Index("idx_agent_tool_thread", "thread_id", "created_at"),
    )

    thread = relationship(
        "AgentThread",
        back_populates="tool_logs",
        foreign_keys=[thread_id],
    )
    job = relationship(
        "AgentJob",
        back_populates="tool_logs",
        foreign_keys=[job_id],
    )


class DailyDigest(Base):
    """Ежедневный AI-анализ городских проблем."""
    __tablename__ = "daily_digests"

    id = Column(Integer, primary_key=True)
    date = Column(DateTime, unique=True, nullable=False)
    total_reports = Column(Integer, default=0)
    top_categories = Column(Text, nullable=True)  # JSON
    top_streets = Column(Text, nullable=True)      # JSON
    mood = Column(String(50), nullable=True)        # спокойное / нейтральное / тревожное
    ai_summary = Column(Text, nullable=True)        # AI-генерированный текст для бегущей строки
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("idx_digest_date", "date"),
    )

