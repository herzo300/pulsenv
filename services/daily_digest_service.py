# services/daily_digest_service.py
"""
Общая логика ежедневной сводки: жалобы за день + анализ городской ситуации + советы.
Используется скриптом daily_digest_telegram.py и ботом (платный раздел).
"""

from datetime import datetime, timezone


def _parse_iso_dt(value):
    if not value:
        return None
    try:
        dt = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:
        return None


def _is_today_utc(created_at) -> bool:
    dt = _parse_iso_dt(created_at)
    if not dt:
        return False
    return dt.date() == datetime.now(timezone.utc).date()


async def get_today_complaints(limit: int = 500):
    from backend.database import SessionLocal
    from backend.models import Report
    today = datetime.now(timezone.utc).date()
    db = SessionLocal()
    try:
        reports = db.query(Report).filter(
            Report.created_at >= datetime(today.year, today.month, today.day, tzinfo=timezone.utc)
        ).order_by(Report.created_at.desc()).limit(limit).all()
        return [
            {
                "category": r.category,
                "summary": r.title,
                "description": r.description,
                "address": r.address,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in reports
        ]
    finally:
        db.close()


async def generate_today_digest_text() -> str:
    """Формирует текст сводки за сегодня (без использования OpenRouter)."""
    complaints = await get_today_complaints(limit=500)
    day_str = datetime.now(timezone.utc).strftime("%d.%m.%Y")
    
    if not complaints:
         return f"Сводка за {day_str}:\nЗа сегодня жалоб не поступило."
    
    lines = [f"Сводка за {day_str}. Всего жалоб за день: {len(complaints)}.\n"]
    for i, c in enumerate(complaints[:20], 1):
        cat = c.get("category") or "—"
        summary = (c.get("summary") or c.get("description") or c.get("text") or "")[:150]
        addr = c.get("address") or ""
        lines.append(f"{i}. [{cat}] {addr or 'без адреса'} | {summary}")
        
    return "\n".join(lines)
