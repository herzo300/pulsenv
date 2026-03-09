# services/Backend/routers/reports.py — API роутер для жалоб/отчётов
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from backend.database import get_db
from backend.models import Report

router = APIRouter(tags=["reports"])


@router.get("/reports")
async def get_reports(
    category: str | None = None,
    status: str | None = None,
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    """Список жалоб для API/карты"""
    query = db.query(Report).order_by(Report.created_at.desc())
    if category:
        query = query.filter(Report.category == category)
    if status:
        query = query.filter(Report.status == status)
    reports = query.limit(limit).all()
    return [r.to_dict() for r in reports]


@router.get("/reports/{report_id}")
async def get_report(report_id: int, db: Session = Depends(get_db)):
    """Одна жалоба по ID"""
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Not found")
    return report.to_dict()
