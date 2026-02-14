# backend/complaint_service.py
"""Сервис для работы с жалобами (CRUD операции)"""

from typing import List, Dict, Any, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from .database import SessionLocal
from .models import Report, User
import json


class ComplaintService:
    """Сервис для работы с жалобами"""
    
    @staticmethod
    def create_complaint(
        db: Session,
        title: str,
        description: Optional[str],
        latitude: Optional[float],
        longitude: Optional[float],
        category: str = "Прочее",
        status: str = "open",
        source: str = "telegram_monitoring",
        user_id: Optional[int] = None,
        telegram_message_id: Optional[str] = None,
        telegram_channel: Optional[str] = None,
        nvd_vulnerability_ids: Optional[List[str]] = None,
    ) -> Optional[Report]:
        """
        Создать новую жалобу
        """
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
            print(f"❌ Ошибка создания жалобы: {e}")
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
    ) -> List[Dict[str, Any]]:
        """
        Получить список жалоб с фильтрацией
        """
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
            
            query = query.order_by(Report.created_at.desc()).offset(offset).limit(limit)
            reports = query.all()
            
            result = []
            for report in reports:
                result.append({
                    "id": report.id,
                    "title": report.title,
                    "description": report.description,
                    "latitude": float(report.lat) if report.lat else None,
                    "longitude": float(report.lng) if report.lng else None,
                    "address": report.address if hasattr(report, 'address') else None,
                    "category": report.category,
                    "status": report.status,
                    "created_at": report.created_at.isoformat() if report.created_at else None,
                    "source": report.source,
                    "user_id": report.user_id,
                    "telegram_message_id": report.telegram_message_id,
                    "telegram_channel": report.telegram_channel,
                })
            
            return {
                "success": True,
                "data": result,
                "count": len(result),
                "offset": offset + len(result),
                "limit": limit,
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "data": [],
                "count": 0,
            }
    
    @staticmethod
    def get_complaint_by_id(db: Session, complaint_id: int) -> Optional[Dict[str, Any]]:
        """
        Получить жалобу по ID
        """
        try:
            report = db.query(Report).filter(Report.id == complaint_id).first()
            
            if not report:
                return {
                    "success": False,
                    "error": f"Жалоба с ID {complaint_id} не найдена",
                }
            
            return {
                "success": True,
                "data": {
                    "id": report.id,
                    "title": report.title,
                    "description": report.description,
                    "latitude": float(report.lat) if report.lat else None,
                    "longitude": float(report.lng) if report.lng else None,
                    "address": report.address if hasattr(report, 'address') else None,
                    "category": report.category,
                    "status": report.status,
                    "created_at": report.created_at.isoformat() if report.created_at else None,
                    "source": report.source,
                    "user_id": report.user_id,
                    "telegram_message_id": report.telegram_message_id,
                    "telegram_channel": report.telegram_channel,
                },
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
            }
    
    @staticmethod
    def update_complaint_status(
        db: Session,
        complaint_id: int,
        status: str,
    ) -> Optional[Dict[str, Any]]:
        """
        Обновить статус жалобы
        """
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
            return {
                "success": False,
                "error": str(e),
            }
    
    @staticmethod
    def get_statistics(db: Session, user_id: Optional[int] = None, telegram_channel: Optional[str] = None) -> Dict[str, Any]:
        """
        Получить статистику по жалобам
        """
        try:
            total = db.query(Report).count()
            
            by_category = {}
            for report in db.query(Report).all():
                cat = report.category or "Прочее"
                by_category[cat] = by_category.get(cat, 0) + 1
            
            by_source = {
                "telegram_monitoring": db.query(Report).filter(Report.source == "telegram_monitoring").count(),
            "mobile_app": db.query(Report).filter(Report.source == "mobile_app").count(),
            "web": db.query(Report).filter(Report.source == "web").count(),
            }
            
            by_status = {
                "open": db.query(Report).filter(Report.status == "open").count(),
                "pending": db.query(Report).filter(Report.status == "pending").count(),
                "resolved": db.query(Report).filter(Report.status == "resolved").count(),
            }
            
            by_channel = {}
            for report in db.query(Report).filter(Report.telegram_channel.isnot(None)).all():
                channel = report.telegram_channel or "unknown"
                by_channel[channel] = by_channel.get(channel, 0) + 1
            
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
            return {
                "success": False,
                "error": str(e),
                "statistics": {},
            }


__all__ = [
    'create_complaint',
    'get_complaints',
    'get_complaint_by_id',
    'update_complaint_status',
    'get_statistics',
]
