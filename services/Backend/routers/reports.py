# services/Backend/routers/reports.py — API роутер для жалоб/отчётов
import logging

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from backend.database import get_db
from backend.models import Report

router = APIRouter(tags=["reports"])
logger = logging.getLogger(__name__)


@router.get("/reports")
async def get_reports(
    category: str | None = None,
    status: str | None = None,
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    """Список жалоб для API/карты."""
    try:
        query = db.query(Report).order_by(Report.created_at.desc())
        if category:
            query = query.filter(Report.category == category)
        if status:
            query = query.filter(Report.status == status)
        reports = query.limit(limit).all()
        return [r.to_dict() for r in reports]
    except Exception as exc:  # pragma: no cover - runtime DB dependent
        logger.warning("Failed to load reports list: %s", exc)
        # Keep API stable for mobile clients if primary DB is temporarily unavailable.
        return []


@router.get("/reports/{report_id}")
async def get_report(report_id: int, db: Session = Depends(get_db)):
    """Одна жалоба по ID."""
    try:
        report = db.query(Report).filter(Report.id == report_id).first()
    except Exception as exc:  # pragma: no cover - runtime DB dependent
        logger.warning("Failed to load report by id=%s: %s", report_id, exc)
        raise HTTPException(
            status_code=503,
            detail="Reports storage unavailable",
        ) from exc
    if not report:
        raise HTTPException(status_code=404, detail="Not found")
    return report.to_dict()
