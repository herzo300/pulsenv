import os
from fastapi import FastAPI, Depends, Query
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from .database import SessionLocal
from .models import Report
import sys
from cachetools import TTLCache

app = FastAPI(title="Пульс города — Нижневартовск API")

# CORS — разрешаем запросы с любых источников (для карты)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Раздаём папку web/ по маршруту /map
_web_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "web")
if os.path.isdir(_web_dir):
    app.mount("/map", StaticFiles(directory=_web_dir, html=True), name="map")

_cluster_cache = TTLCache(maxsize=100, ttl=300)  # 5 минут


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _report_to_dict(r: Report) -> dict:
    return {
        "id": r.id,
        "title": r.title,
        "description": r.description,
        "latitude": float(r.lat) if r.lat is not None else None,
        "longitude": float(r.lng) if r.lng is not None else None,
        "category": r.category,
        "status": r.status,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    }


@app.get("/complaints")
async def read_complaints(
    category: str | None = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    """Отдает список жалоб с пагинацией"""
    query = db.query(Report)

    if category:
        query = query.filter(Report.category == category)

    offset = (page - 1) * per_page
    reports = query.order_by(Report.created_at.desc()).offset(offset).limit(per_page).all()
    
    total = query.count()
    
    return {
        "data": [_report_to_dict(r) for r in reports],
        "pagination": {
            "page": page,
            "per_page": per_page,
            "total": total,
            "pages": (total + per_page - 1) // per_page,
        }
    }


@app.get("/complaints/clusters")
async def read_clusters(db: Session = Depends(get_db)):
    """Кластеры жалоб для карты с кэшированием"""
    cache_key = "complaints_clusters"
    if cache_key in _cluster_cache:
        return _cluster_cache[cache_key]
    
    try:
        from services.cluster_service import cluster_complaints
    except ImportError:
        reports = db.query(Report).all()
        clusters = []
        for i, r in enumerate(reports):
            clusters.append({
                "cluster_id": i,
                "center_lat": float(r.lat) if r.lat is not None else 0.0,
                "center_lon": float(r.lng) if r.lng is not None else 0.0,
                "complaints_count": 1,
                "complaints": [_report_to_dict(r)],
            })
        _cluster_cache[cache_key] = clusters
        return clusters

    reports = db.query(Report).limit(500).all()
    complaints_list = [_report_to_dict(r) for r in reports]

    if not complaints_list:
        clusters = []
        _cluster_cache[cache_key] = clusters
        return []

    clusters = cluster_complaints(complaints_list, min_cluster_size=1, min_samples=1)

    if not clusters:
        clusters = [
            {
                "cluster_id": i,
                "center_lat": c["latitude"],
                "center_lon": c["longitude"],
                "complaints_count": 1,
                "complaints": [c],
            }
            for i, c in enumerate(complaints_list)
        ]
    
    _cluster_cache[cache_key] = clusters
    return clusters


@app.get("/stats")
async def get_stats(db: Session = Depends(get_db)):
    """Статистика для админ-панели"""
    total = db.query(Report).count()
    return {"total": total}


@app.get("/api/reports")
async def api_reports(db: Session = Depends(get_db)):
    """Плоский список жалоб для карты"""
    reports = db.query(Report).order_by(Report.created_at.desc()).limit(500).all()
    return [_report_to_dict(r) for r in reports]


@app.get("/complaints/list")
async def complaints_list(
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    """Список жалоб (совместимость со старой картой)"""
    reports = db.query(Report).order_by(Report.created_at.desc()).limit(limit).all()
    return {
        "success": True,
        "data": [_report_to_dict(r) for r in reports],
    }
