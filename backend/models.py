from datetime import datetime
from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint, Index
from sqlalchemy.orm import relationship

from .database import Base


class User(Base):
    """Модель пользователя"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    telegram_id = Column(Integer, unique=True, nullable=True)
    username = Column(String(100), unique=True, nullable=True)
    first_name = Column(String(100))
    last_name = Column(String(100))
    photo_url = Column(String(500), nullable=True)
    balance = Column(Integer, default=0)  # баланс в Stars
    notify_new = Column(Integer, default=0)  # 1 = подписка на уведомления о новых жалобах
    created_at = Column(DateTime, default=datetime.utcnow)

    # Отношения
    reports = relationship("Report", back_populates="user")
    likes = relationship("Like", back_populates="user")
    comments = relationship("Comment", back_populates="user")


class Report(Base):
    """Модель жалобы"""
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
    supporters = Column(Integer, default=0)  # кол-во присоединившихся
    supporters_notified = Column(Integer, default=0)  # 1 = email отправлен при 10+
    uk_name = Column(String(300), nullable=True)
    uk_email = Column(String(200), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index('idx_category', 'category'),
        Index('idx_status', 'status'),
        Index('idx_created_at', 'created_at'),
        Index('idx_user_id', 'user_id'),
        Index('idx_lat_lng', 'lat', 'lng'),
    )

    # Отношения
    user = relationship("User", back_populates="reports")
    likes = relationship("Like", back_populates="report", cascade="all, delete-orphan")
    comments = relationship("Comment", back_populates="report", cascade="all, delete-orphan")

    @property
    def likes_count(self):
        return len(self.likes) if self.likes else 0

    @property
    def comments_count(self):
        return len(self.comments) if self.comments else 0


class Like(Base):
    """Модель лайка"""
    __tablename__ = "likes"

    id = Column(Integer, primary_key=True)
    report_id = Column(Integer, ForeignKey("reports.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint('report_id', 'user_id', name='unique_like'),
    )

    # Отношения
    report = relationship("Report", back_populates="likes")
    user = relationship("User", back_populates="likes")


class Comment(Base):
    """Модель комментария"""
    __tablename__ = "comments"

    id = Column(Integer, primary_key=True)
    report_id = Column(Integer, ForeignKey("reports.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    text = Column(Text, nullable=False)
    parent_id = Column(Integer, ForeignKey("comments.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Отношения
    report = relationship("Report", back_populates="comments")
    user = relationship("User", back_populates="comments")
    parent = relationship("Comment", remote_side=[id], backref="replies")
