"""Live city pulse metrics for map + infographic hero blocks."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from services.data_layer.database import get_db
from services.data_layer.models import Report

router = APIRouter(tags=["pulse-stats"])


@router.get("/api/pulse/stats")
def get_pulse_stats(db: Session = Depends(get_db)) -> dict:
    """Aggregated complaint metrics from PostgreSQL/SQLite."""
    now = datetime.now(UTC).replace(tzinfo=None)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    month_start = now - timedelta(days=30)

    total = db.query(func.count(Report.id)).scalar() or 0
    today_count = (
        db.query(func.count(Report.id))
        .filter(Report.created_at >= today_start)
        .scalar()
        or 0
    )
    month_count = (
        db.query(func.count(Report.id))
        .filter(Report.created_at >= month_start)
        .scalar()
        or 0
    )

    in_work_count = (
        db.query(func.count(Report.id))
        .filter(Report.status.in_(["open", "в работе", "новая", "в_работе"]))
        .scalar()
        or 0
    )
    resolved_count = (
        db.query(func.count(Report.id))
        .filter(Report.status.in_(["resolved", "решена", "закрыта", "решено"]))
        .scalar()
        or 0
    )

    with_coords = (
        db.query(func.count(Report.id))
        .filter(Report.lat.isnot(None), Report.lng.isnot(None))
        .scalar()
        or 0
    )
    with_address = (
        db.query(func.count(Report.id))
        .filter(Report.address.isnot(None), Report.address != "")
        .scalar()
        or 0
    )

    top_row = (
        db.query(Report.category, func.count(Report.id).label("cnt"))
        .group_by(Report.category)
        .order_by(func.count(Report.id).desc())
        .first()
    )

    status_rows = (
        db.query(Report.status, func.count(Report.id))
        .group_by(Report.status)
        .all()
    )
    category_rows = (
        db.query(Report.category, func.count(Report.id))
        .group_by(Report.category)
        .order_by(func.count(Report.id).desc())
        .limit(24)
        .all()
    )

    return {
        "total_reports": total,
        "today": today_count,
        "month": month_count,
        "in_work": in_work_count,
        "resolved": resolved_count,
        "with_gps_percent": round(100 * with_coords / total, 1) if total else 0,
        "with_address_percent": round(100 * with_address / total, 1) if total else 0,
        "top_category": top_row[0] if top_row else None,
        "top_category_count": int(top_row[1]) if top_row else 0,
        "by_status": {str(s or "unknown"): int(c) for s, c in status_rows},
        "by_category": {str(c or "Прочее"): int(n) for c, n in category_rows},
        "updated_at": now.isoformat(),
        "hero_kpis": [
            {
                "label": "Сигналы сегодня",
                "value": str(today_count),
                "accent": "cyan",
            },
            {
                "label": "В работе",
                "value": str(in_work_count),
                "accent": "violet",
            },
            {
                "label": "Решенные",
                "value": str(resolved_count),
                "accent": "green",
            },
            {
                "label": "Всего сигналов",
                "value": str(total),
                "accent": "orange",
            },
        ],
    }
