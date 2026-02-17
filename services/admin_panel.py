# services/admin_panel.py
"""
Админ-панель для Telegram бота «Пульс города»
Статистика, управление ботом, просмотр жалоб
"""

import os
import logging
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from sqlalchemy import func, and_
from sqlalchemy.orm import Session
from backend.database import SessionLocal
from backend.models import Report, User
from services.firebase_service import get_recent_complaints
from services.firebase_queue import get_queue_stats, process_queue as process_firebase_queue
from services.ai_cache import get_cache_stats, cleanup_expired as cleanup_ai_cache

logger = logging.getLogger(__name__)

# Импорт из централизованной конфигурации
from core.config import ADMIN_TELEGRAM_IDS as ADMIN_IDS

def is_admin(telegram_id: int) -> bool:
    """Проверяет, является ли пользователь администратором"""
    return telegram_id in ADMIN_IDS


def get_stats(db: Session) -> Dict[str, Any]:
    """Получает статистику по работе приложения"""
    now = datetime.utcnow()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_ago = today - timedelta(days=7)
    month_ago = today - timedelta(days=30)
    
    # Общая статистика
    total_reports = db.query(Report).count()
    total_users = db.query(User).count()
    
    # По статусам
    open_reports = db.query(Report).filter(Report.status == "open").count()
    resolved_reports = db.query(Report).filter(Report.status == "resolved").count()
    pending_reports = db.query(Report).filter(Report.status == "pending").count()
    in_progress_reports = db.query(Report).filter(Report.status == "in_progress").count()
    
    # По категориям (топ-10)
    category_stats = db.query(
        Report.category,
        func.count(Report.id).label('count')
    ).group_by(Report.category).order_by(func.count(Report.id).desc()).limit(10).all()
    
    # По источникам
    source_stats = db.query(
        Report.source,
        func.count(Report.id).label('count')
    ).group_by(Report.source).order_by(func.count(Report.id).desc()).all()
    
    # За сегодня
    today_reports = db.query(Report).filter(Report.created_at >= today).count()
    
    # За неделю
    week_reports = db.query(Report).filter(Report.created_at >= week_ago).count()
    
    # За месяц
    month_reports = db.query(Report).filter(Report.created_at >= month_ago).count()
    
    # Активные пользователи (создали жалобу за последние 7 дней)
    active_users = db.query(func.count(func.distinct(Report.user_id))).filter(
        Report.created_at >= week_ago,
        Report.user_id.isnot(None)
    ).scalar() or 0
    
    # Среднее время решения (для решённых)
    resolved_with_time = db.query(Report).filter(
        Report.status == "resolved",
        Report.created_at.isnot(None),
        Report.updated_at.isnot(None)
    ).all()
    
    avg_resolution_time = None
    if resolved_with_time:
        times = []
        for r in resolved_with_time:
            if r.created_at and r.updated_at:
                delta = (r.updated_at - r.created_at).total_seconds() / 86400  # дни
                if delta > 0:
                    times.append(delta)
        if times:
            avg_resolution_time = sum(times) / len(times)
    
    return {
        "total_reports": total_reports,
        "total_users": total_users,
        "open": open_reports,
        "resolved": resolved_reports,
        "pending": pending_reports,
        "in_progress": in_progress_reports,
        "today": today_reports,
        "week": week_reports,
        "month": month_reports,
        "active_users": active_users,
        "avg_resolution_days": round(avg_resolution_time, 1) if avg_resolution_time else None,
        "by_category": {cat: cnt for cat, cnt in category_stats},
        "by_source": {src: cnt for src, cnt in source_stats},
    }


async def get_firebase_stats() -> Dict[str, Any]:
    """Получает статистику из Firebase"""
    try:
        complaints = await get_recent_complaints(limit=1000)
        if not complaints:
            return {"total": 0, "by_category": {}, "by_status": {}}
        
        by_category = {}
        by_status = {}
        for c in complaints:
            cat = c.get("category", "Прочее")
            by_category[cat] = by_category.get(cat, 0) + 1
            status = c.get("status", "open")
            by_status[status] = by_status.get(status, 0) + 1
        
        return {
            "total": len(complaints),
            "by_category": by_category,
            "by_status": by_status,
        }
    except Exception as e:
        logger.error(f"Firebase stats error: {e}")
        return {"total": 0, "by_category": {}, "by_status": {}}


def format_stats_message(stats: Dict[str, Any], firebase_stats: Optional[Dict[str, Any]] = None) -> str:
    """Форматирует статистику в читаемое сообщение"""
    lines = [
        "📊 *Статистика работы приложения*\n",
        "═══ ОБЩАЯ СТАТИСТИКА ═══",
        f"📝 Всего жалоб: *{stats['total_reports']}*",
        f"👥 Пользователей: *{stats['total_users']}*",
        f"🟢 Активных (7 дней): *{stats['active_users']}*",
        "",
        "═══ ПО СТАТУСАМ ═══",
        f"🔴 Открыто: *{stats['open']}*",
        f"🟡 В обработке: *{stats['pending']}*",
        f"🟠 В работе: *{stats['in_progress']}*",
        f"✅ Решено: *{stats['resolved']}*",
    ]
    
    if stats.get('avg_resolution_days'):
        lines.append(f"⏱️ Среднее время решения: *{stats['avg_resolution_days']}* дней")
    
    lines.extend([
        "",
        "═══ ПО ПЕРИОДАМ ═══",
        f"📅 Сегодня: *{stats['today']}*",
        f"📅 За неделю: *{stats['week']}*",
        f"📅 За месяц: *{stats['month']}*",
    ])
    
    if stats.get('by_category'):
        lines.extend([
            "",
            "═══ ТОП-10 КАТЕГОРИЙ ═══",
        ])
        for i, (cat, cnt) in enumerate(list(stats['by_category'].items())[:10], 1):
            pct = round(cnt / stats['total_reports'] * 100, 1) if stats['total_reports'] > 0 else 0
            lines.append(f"{i}. {cat}: *{cnt}* ({pct}%)")
    
    if stats.get('by_source'):
        lines.extend([
            "",
            "═══ ПО ИСТОЧНИКАМ ═══",
        ])
        for src, cnt in list(stats['by_source'].items())[:10]:
            lines.append(f"• {src}: *{cnt}*")
    
    if firebase_stats:
        lines.extend([
            "",
            "═══ FIREBASE (REALTIME) ═══",
            f"📊 Всего в Firebase: *{firebase_stats.get('total', 0)}*",
        ])
        if firebase_stats.get('by_status'):
            for status, cnt in firebase_stats['by_status'].items():
                lines.append(f"• {status}: *{cnt}*")
    
    return "\n".join(lines)


def get_recent_reports(db: Session, limit: int = 10) -> List[Report]:
    """Получает последние жалобы"""
    return db.query(Report).order_by(Report.created_at.desc()).limit(limit).all()


def format_report_message(report: Report) -> str:
    """Форматирует жалобу в сообщение"""
    status_icon = {
        "open": "🔴",
        "pending": "🟡",
        "in_progress": "🟠",
        "resolved": "✅",
    }.get(report.status, "⚪")
    
    lines = [
        f"{status_icon} *Жалоба #{report.id}*",
        f"📋 Категория: {report.category}",
        f"📍 Адрес: {report.address or 'не указан'}",
        f"📝 {report.title or ''}",
    ]
    
    if report.lat and report.lng:
        lines.append(f"🗺️ Координаты: {report.lat:.5f}, {report.lng:.5f}")
    
    if report.uk_name:
        lines.append(f"🏢 УК: {report.uk_name}")
    
    if report.source:
        lines.append(f"📡 Источник: {report.source}")
    
    if report.created_at:
        lines.append(f"🕐 Создана: {report.created_at.strftime('%d.%m.%Y %H:%M')}")
    
    if report.status == "resolved" and report.updated_at:
        lines.append(f"✅ Решена: {report.updated_at.strftime('%d.%m.%Y %H:%M')}")
    
    return "\n".join(lines)


# ═══ УПРАВЛЕНИЕ БОТОМ ═══

# Флаг состояния мониторинга (в реальном приложении лучше хранить в БД или Redis)
_monitoring_enabled = True

def is_monitoring_enabled() -> bool:
    """Проверяет, включен ли мониторинг"""
    return _monitoring_enabled

def toggle_monitoring() -> bool:
    """Переключает состояние мониторинга"""
    global _monitoring_enabled
    _monitoring_enabled = not _monitoring_enabled
    return _monitoring_enabled

def get_bot_status() -> Dict[str, Any]:
    """Получает статус бота"""
    db = SessionLocal()
    try:
        stats = get_stats(db)
        firebase_queue = get_queue_stats()
        ai_cache = get_cache_stats()
        return {
            "monitoring_enabled": _monitoring_enabled,
            "total_reports": stats["total_reports"],
            "total_users": stats["total_users"],
            "open_reports": stats["open"],
            "resolved_reports": stats["resolved"],
            "firebase_queue_size": firebase_queue["size"],
            "ai_cache_size": ai_cache["total"],
            "ai_cache_valid": ai_cache["valid"],
        }
    finally:
        db.close()


def export_stats_csv(db: Session) -> str:
    """Экспортирует статистику в CSV формат"""
    import csv
    import io
    
    reports = db.query(Report).order_by(Report.created_at.desc()).all()
    
    output = io.StringIO()
    writer = csv.writer(output)
    
    # Заголовки
    writer.writerow([
        "ID", "Категория", "Статус", "Адрес", "Широта", "Долгота",
        "УК", "Источник", "Создана", "Обновлена", "Заголовок"
    ])
    
    # Данные
    for r in reports:
        writer.writerow([
            r.id,
            r.category or "",
            r.status or "",
            r.address or "",
            r.lat or "",
            r.lng or "",
            r.uk_name or "",
            r.source or "",
            r.created_at.strftime("%Y-%m-%d %H:%M:%S") if r.created_at else "",
            r.updated_at.strftime("%Y-%m-%d %H:%M:%S") if r.updated_at else "",
            (r.title or "")[:100],  # Ограничиваем длину
        ])
    
    return output.getvalue()


def clear_old_reports(db: Session, days: int = 90) -> int:
    """Удаляет старые решённые жалобы (старше N дней)"""
    from datetime import datetime, timedelta
    
    cutoff_date = datetime.utcnow() - timedelta(days=days)
    
    deleted = db.query(Report).filter(
        Report.status == "resolved",
        Report.updated_at < cutoff_date
    ).delete()
    
    db.commit()
    return deleted
