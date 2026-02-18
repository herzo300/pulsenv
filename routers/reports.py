# routers/reports.py — API роутер для жалоб/отчётов
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from backend.database import get_db
from backend.models import Report


router = APIRouter(tags=["reports"])


def _report_to_dict(r: Report) -> dict:
    return {
        "id": r.id,
        "title": r.title,
        "description": r.description,
        "latitude": float(r.lat) if r.lat is not None else None,
        "longitude": float(r.lng) if r.lng is not None else None,
        "address": r.address,
        "category": r.category,
        "status": r.status,
        "source": r.source,
        "created_at": r.created_at.isoformat() if r.created_at else None,
        "updated_at": r.updated_at.isoformat() if r.updated_at else None,
    }


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
    return [_report_to_dict(r) for r in reports]


@router.get("/reports/{report_id}")
async def get_report(report_id: int, db: Session = Depends(get_db)):
    """Одна жалоба по ID"""
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Not found")
    return _report_to_dict(report)
