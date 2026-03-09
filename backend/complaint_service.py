# backend/complaint_service.py
"""
Complaint CRUD service — works with the local SQLAlchemy database.
"""

import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from .models import Report

logger = logging.getLogger(__name__)


class ComplaintService:
    """Service for CRUD operations on complaints (reports)."""

    @staticmethod
    def create_complaint(
        db: Session,
        title: str,
        description: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        category: str = "Прочее",
        status: str = "open",
        source: str = "telegram_monitoring",
        user_id: Optional[int] = None,
        telegram_message_id: Optional[str] = None,
        telegram_channel: Optional[str] = None,
        nvd_vulnerability_ids: Optional[List[str]] = None,
    ) -> Optional[Report]:
        """Create a new complaint record."""
        try:
            db_report = Report(
                title=title,
                description=description,
                lat=latitude,
                lng=longitude,
                category=category,
                status=status,
                source=source,
                user_id=user_id,
                telegram_message_id=telegram_message_id,
                telegram_channel=telegram_channel,
            )
            db.add(db_report)
            db.commit()
            db.refresh(db_report)
            return db_report
        except Exception as e:
            db.rollback()
            logger.error("Error creating complaint: %s", e)
            return None

    @staticmethod
    def get_complaints(
        db: Session,
        category: Optional[str] = None,
        status: Optional[str] = None,
        limit: int = 100,
        offset: int = 0,
        user_id: Optional[int] = None,
        telegram_channel: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Get a paginated/filtered list of complaints."""
        try:
            query = db.query(Report)

            if category:
                query = query.filter(Report.category == category)
            if status:
                query = query.filter(Report.status == status)
            if user_id:
                query = query.filter(Report.user_id == user_id)
            if telegram_channel:
                query = query.filter(Report.telegram_channel == telegram_channel)

            reports = (
                query.order_by(Report.created_at.desc())
                .offset(offset)
                .limit(limit)
                .all()
            )

            result = [r.to_dict() for r in reports]
            return {
                "success": True,
                "data": result,
                "count": len(result),
                "offset": offset + len(result),
                "limit": limit,
            }
        except Exception as e:
            logger.error("Error fetching complaints: %s", e)
            return {"success": False, "error": str(e), "data": [], "count": 0}

    @staticmethod
    def get_complaint_by_id(
        db: Session, complaint_id: int
    ) -> Dict[str, Any]:
        """Get a single complaint by its ID."""
        try:
            report = db.query(Report).filter(Report.id == complaint_id).first()
            if not report:
                return {
                    "success": False,
                    "error": f"Жалоба с ID {complaint_id} не найдена",
                }
            return {
                "success": True,
                "data": report.to_dict(),
            }
        except Exception as e:
            logger.error("Error fetching complaint #%d: %s", complaint_id, e)
            return {"success": False, "error": str(e)}

    @staticmethod
    def update_complaint_status(
        db: Session, complaint_id: int, status: str
    ) -> Dict[str, Any]:
        """Update the status of a complaint."""
        try:
            report = db.query(Report).filter(Report.id == complaint_id).first()
            if not report:
                return {
                    "success": False,
                    "error": f"Жалоба с ID {complaint_id} не найдена",
                }
            report.status = status
            report.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(report)
            return {
                "success": True,
                "data": {
                    "id": report.id,
                    "status": status,
                    "updated_at": report.updated_at.isoformat(),
                },
            }
        except Exception as e:
            db.rollback()
            logger.error("Error updating complaint #%d: %s", complaint_id, e)
            return {"success": False, "error": str(e)}

    @staticmethod
    def get_statistics(
        db: Session,
        user_id: Optional[int] = None,
        telegram_channel: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Get complaint statistics using aggregate queries (not N+1).
        """
        try:
            total = db.query(func.count(Report.id)).scalar() or 0

            # Category breakdown via GROUP BY
            cat_rows = (
                db.query(Report.category, func.count(Report.id))
                .group_by(Report.category)
                .all()
            )
            by_category = {cat or "Прочее": cnt for cat, cnt in cat_rows}

            # Source breakdown via GROUP BY
            src_rows = (
                db.query(Report.source, func.count(Report.id))
                .group_by(Report.source)
                .all()
            )
            by_source = {src or "unknown": cnt for src, cnt in src_rows}

            # Status breakdown via GROUP BY
            status_rows = (
                db.query(Report.status, func.count(Report.id))
                .group_by(Report.status)
                .all()
            )
            by_status = {st or "unknown": cnt for st, cnt in status_rows}

            # Channel breakdown via GROUP BY
            channel_rows = (
                db.query(Report.telegram_channel, func.count(Report.id))
                .filter(Report.telegram_channel.isnot(None))
                .group_by(Report.telegram_channel)
                .all()
            )
            by_channel = {ch or "unknown": cnt for ch, cnt in channel_rows}

            return {
                "success": True,
                "statistics": {
                    "total": total,
                    "by_category": by_category,
                    "by_source": by_source,
                    "by_status": by_status,
                    "by_channel": by_channel,
                },
            }
        except Exception as e:
            logger.error("Error computing statistics: %s", e)
            return {"success": False, "error": str(e), "statistics": {}}


__all__ = ["ComplaintService"]
