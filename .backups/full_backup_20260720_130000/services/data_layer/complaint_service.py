# backend/complaint_service.py
"""
Complaint CRUD service — works with the local SQLAlchemy database.
"""

import logging
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from .models import Report

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    """Timezone-aware UTC now to replace deprecated datetime.utcnow()."""
    return datetime.now(UTC)


class ComplaintService:
    """Service for CRUD operations on complaints (reports)."""

    @staticmethod
    def create_complaint(
        db: Session,
        title: str,
        description: str | None = None,
        address: str | None = None,
        latitude: float | None = None,
        longitude: float | None = None,
        category: str = "Прочее",
        status: str = "open",
        source: str = "telegram_monitoring",
        user_id: int | None = None,
        telegram_message_id: str | None = None,
        telegram_channel: str | None = None,
        nvd_vulnerability_ids: list[str] | None = None,
    ) -> Report | None:
        """Create a new complaint record."""
        # UK Lookup (async-safe: use asyncio.to_thread instead of asyncio.run)
        uk_name = None
        uk_email = None
        if latitude is not None and longitude is not None:
            try:
                from services.uk_service import find_uk_by_coords
                uk_info = find_uk_by_coords(latitude, longitude)
                if uk_info:
                    uk_name = uk_info.get("name")
                    uk_email = uk_info.get("email")
            except Exception as e:
                logger.warning("Auto-UK lookup failed during creation: %s", e)

        # Trim trailing whitespace / newlines
        clean_description = description.strip() if description else None

        try:
            db_report = Report(
                title=title,
                description=clean_description,
                address=address,
                lat=latitude,
                lng=longitude,
                category=category,
                status=status,
                source=source,
                user_id=user_id,
                telegram_message_id=telegram_message_id,
                telegram_channel=telegram_channel,
                uk_name=uk_name,
                uk_email=uk_email,
            )
            db.add(db_report)
            db.commit()
            db.refresh(db_report)

            # Trigger background AI image generation if no photo is attached
            if clean_description and "Фото:" not in clean_description and "http" not in clean_description:
                try:
                    import asyncio
                    from services.business.image_generator import generate_ai_image_for_description
                    
                    try:
                        loop = asyncio.get_running_loop()
                        
                        async def run_gen_and_update(report_id, desc_text, cat):
                            from services.data_layer.database import SessionLocal
                            img_url = await generate_ai_image_for_description(desc_text, cat)
                            if img_url:
                                db_bg = SessionLocal()
                                try:
                                    rep = db_bg.query(Report).filter(Report.id == report_id).first()
                                    if rep:
                                        rep.description = f"{rep.description}\nФото: {img_url}"
                                        db_bg.commit()
                                except Exception as bg_err:
                                    logger.warning(f"Failed to update generated image in DB: {bg_err}")
                                finally:
                                    db_bg.close()
                        
                        loop.create_task(run_gen_and_update(db_report.id, clean_description, category))
                    except RuntimeError:
                        # Fallback if no loop is running
                        img_url = asyncio.run(generate_ai_image_for_description(clean_description, category))
                        if img_url:
                            db_report.description = f"{db_report.description}\nФото: {img_url}"
                            db.commit()
                            db.refresh(db_report)
                except Exception as gen_launch_err:
                    logger.warning("Background AI image generation launch failed: %s", gen_launch_err)

            return db_report
        except Exception as e:
            db.rollback()
            logger.error("Error creating complaint: %s", e)
            return None

    @staticmethod
    def grant_vip_reward_for_report(db: Session, user_id: int) -> str | None:
        """Grant VIP monitoring minutes for valid reporting."""
        from .models import User, VipSubscription
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if user and user.telegram_id:
                sub = db.query(VipSubscription).filter(VipSubscription.telegram_id == user.telegram_id).first()
                if not sub:
                    sub = VipSubscription(
                        telegram_id=user.telegram_id,
                        tier="free",
                        ai_minutes_total=90,
                        expires_at=_utcnow() + timedelta(days=365),
                    )
                    db.add(sub)
                else:
                    sub.ai_minutes_total += 30
                db.commit()
                return "🎁 Вам начислено 30 минут ИИ-обработки за помощь городу!"
            return None
        except Exception as e:
            db.rollback()
            logger.error("Error granting VIP reward: %s", e)
            return None

    @staticmethod
    def get_complaints(
        db: Session,
        category: str | None = None,
        status: str | None = None,
        limit: int = 100,
        offset: int = 0,
        user_id: int | None = None,
        telegram_channel: str | None = None,
    ) -> dict[str, Any]:
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
    def get_complaint_by_id(db: Session, complaint_id: int) -> dict[str, Any]:
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
    ) -> dict[str, Any]:
        """Update the status of a complaint."""
        try:
            report = db.query(Report).filter(Report.id == complaint_id).first()
            if not report:
                return {
                    "success": False,
                    "error": f"Жалоба с ID {complaint_id} не найдена",
                }
            report.status = status
            report.updated_at = _utcnow()
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
        user_id: int | None = None,
        telegram_channel: str | None = None,
    ) -> dict[str, Any]:
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
