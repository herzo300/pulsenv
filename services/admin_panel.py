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

# Файл для хранения версии Web App (карта/инфографика)
_WEBAPP_VERSION_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "data", "webapp_version.json"
)

# Файл для отчётов об обновлениях бота
_BOT_UPDATE_REPORTS_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "data", "bot_update_reports.json"
)

def _ensure_data_dir():
    d = os.path.dirname(_WEBAPP_VERSION_FILE)
    if not os.path.exists(d):
        os.makedirs(d, exist_ok=True)

def get_webapp_version() -> int:
    """Возвращает текущую версию для URL карты и инфографики (обход кэша)."""
    _ensure_data_dir()
    try:
        if os.path.exists(_WEBAPP_VERSION_FILE):
            with open(_WEBAPP_VERSION_FILE, "r", encoding="utf-8") as f:
                data = __import__("json").load(f)
                return int(data.get("version", 1))
    except Exception:
        pass
    return int(__import__("time").time())

def bump_webapp_version() -> int:
    """Увеличивает версию Web App. Вызывать после деплоя worker."""
    import time
    import json
    _ensure_data_dir()
    v = max(get_webapp_version(), int(time.time())) + 1
    try:
        with open(_WEBAPP_VERSION_FILE, "w", encoding="utf-8") as f:
            json.dump({"version": v, "updated_at": datetime.utcnow().isoformat()}, f, ensure_ascii=False)
    except Exception as e:
        logger.warning(f"Could not save webapp version: {e}")
    return v


def save_bot_update_report(success: bool, webapp_version: int, details: str, error: Optional[str] = None) -> None:
    """Сохраняет отчёт об обновлении бота для админ-панели."""
    import json
    _ensure_data_dir()
    report = {
        "success": success,
        "webapp_version": webapp_version,
        "details": details,
        "error": error,
        "timestamp": datetime.utcnow().isoformat(),
    }
    try:
        reports = []
        if os.path.exists(_BOT_UPDATE_REPORTS_FILE):
            with open(_BOT_UPDATE_REPORTS_FILE, "r", encoding="utf-8") as f:
                reports = json.load(f)
        reports.insert(0, report)
        reports = reports[:50]  # храним последние 50
        with open(_BOT_UPDATE_REPORTS_FILE, "w", encoding="utf-8") as f:
            json.dump(reports, f, ensure_ascii=False, indent=2)
    except Exception as e:
        logger.warning(f"Could not save bot update report: {e}")


def get_last_bot_update_reports(limit: int = 5) -> List[Dict[str, Any]]:
    """Возвращает последние отчёты об обновлениях бота."""
    import json
    try:
        if os.path.exists(_BOT_UPDATE_REPORTS_FILE):
            with open(_BOT_UPDATE_REPORTS_FILE, "r", encoding="utf-8") as f:
                reports = json.load(f)
                return reports[:limit]
    except Exception:
        pass
    return []


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


def export_complaints_pdf(db: Session, days: Optional[int] = None, limit: Optional[int] = None) -> bytes:
    """Экспортирует краткую сводку по жалобам в формате PDF"""
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.units import mm
        from reportlab.lib import colors
        from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, PageBreak
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
        from datetime import datetime, timedelta
        import io
        
        # Подготовка данных
        query = db.query(Report)
        
        if days:
            cutoff_date = datetime.utcnow() - timedelta(days=days)
            query = query.filter(Report.created_at >= cutoff_date)
        
        reports = query.order_by(Report.created_at.desc()).limit(limit).all() if limit else query.order_by(Report.created_at.desc()).all()
        
        # Статистика
        stats = get_stats(db)
        
        # Создание PDF в памяти
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4, topMargin=20*mm, bottomMargin=20*mm)
        story = []
        
        # Стили
        styles = getSampleStyleSheet()
        title_style = ParagraphStyle(
            'CustomTitle',
            parent=styles['Heading1'],
            fontSize=20,
            textColor=colors.HexColor('#1a1a2e'),
            spaceAfter=12,
            alignment=TA_CENTER,
            fontName='Helvetica-Bold'
        )
        heading_style = ParagraphStyle(
            'CustomHeading',
            parent=styles['Heading2'],
            fontSize=14,
            textColor=colors.HexColor('#0f3460'),
            spaceAfter=8,
            fontName='Helvetica-Bold'
        )
        normal_style = styles['Normal']
        normal_style.fontSize = 10
        normal_style.leading = 12
        
        # Заголовок
        story.append(Paragraph("📊 Краткая сводка по жалобам", title_style))
        story.append(Paragraph(f"<i>Дата формирования: {datetime.now().strftime('%d.%m.%Y %H:%M')}</i>", normal_style))
        story.append(Spacer(1, 12))
        
        # Общая статистика
        story.append(Paragraph("Общая статистика", heading_style))
        stats_data = [
            ["Показатель", "Значение"],
            ["Всего жалоб", str(stats['total_reports'])],
            ["Пользователей", str(stats['total_users'])],
            ["Открыто", str(stats['open'])],
            ["В обработке", str(stats['pending'])],
            ["В работе", str(stats['in_progress'])],
            ["Решено", str(stats['resolved'])],
            ["За сегодня", str(stats['today'])],
            ["За неделю", str(stats['week'])],
            ["За месяц", str(stats['month'])],
        ]
        if stats.get('avg_resolution_days'):
            stats_data.append(["Среднее время решения", f"{stats['avg_resolution_days']} дней"])
        
        stats_table = Table(stats_data, colWidths=[120*mm, 70*mm])
        stats_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#0f3460')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 11),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
            ('GRID', (0, 0), (-1, -1), 1, colors.grey),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f5f5f5')]),
        ]))
        story.append(stats_table)
        story.append(Spacer(1, 12))
        
        # Топ категорий
        if stats.get('by_category'):
            story.append(Paragraph("Топ категорий", heading_style))
            category_data = [["Категория", "Количество", "%"]]
            total = stats['total_reports']
            for cat, cnt in list(stats['by_category'].items())[:10]:
                pct = round((cnt / total * 100), 1) if total > 0 else 0
                category_data.append([cat, str(cnt), f"{pct}%"])
            
            cat_table = Table(category_data, colWidths=[100*mm, 50*mm, 40*mm])
            cat_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#16213e')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('ALIGN', (1, 1), (2, -1), 'RIGHT'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 10),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 10),
                ('BACKGROUND', (0, 1), (-1, -1), colors.white),
                ('GRID', (0, 0), (-1, -1), 1, colors.grey),
            ]))
            story.append(cat_table)
            story.append(Spacer(1, 12))
        
        # Список жалоб (краткий)
        if reports:
            story.append(Paragraph(f"Последние жалобы ({len(reports)} из {stats['total_reports']})", heading_style))
            complaints_data = [["ID", "Категория", "Статус", "Адрес", "Дата"]]
            
            for r in reports[:50]:  # Ограничиваем до 50 для читаемости
                date_str = r.created_at.strftime("%d.%m.%Y") if r.created_at else ""
                address = (r.address or "")[:30] + "..." if r.address and len(r.address) > 30 else (r.address or "")
                complaints_data.append([
                    str(r.id),
                    r.category or "—",
                    r.status or "—",
                    address,
                    date_str
                ])
            
            complaints_table = Table(complaints_data, colWidths=[15*mm, 35*mm, 25*mm, 60*mm, 25*mm])
            complaints_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1a1a2e')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('ALIGN', (0, 1), (0, -1), 'CENTER'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 9),
                ('FONTSIZE', (0, 1), (-1, -1), 8),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
                ('BACKGROUND', (0, 1), (-1, -1), colors.white),
                ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f9f9f9')]),
            ]))
            story.append(complaints_table)
        
        # Построение PDF
        doc.build(story)
        buffer.seek(0)
        return buffer.getvalue()
        
    except ImportError:
        logger.error("reportlab not installed. Install with: pip install reportlab")
        raise
    except Exception as e:
        logger.error(f"PDF export error: {e}")
        raise


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
