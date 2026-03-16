from datetime import datetime

from sqlalchemy import (
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
