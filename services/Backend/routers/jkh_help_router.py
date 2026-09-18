"""
Server-backed Neighborhood Help Requests Router (ЖКХ Взаимопомощь).
Persists neighborhood help requests and manages status stages:
  - pending (Ожидает помощи): Amber / Orange badge
  - claimed / in_progress (Взято в работу): Purple / Violet badge
  - completed (Выполнено): Emerald / Green badge
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, List, Optional
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy import Column, Integer, String, DateTime, Text
from services.data_layer.database import Base, SessionLocal, engine

router = APIRouter(prefix="/api/jkh", tags=["jkh-help"])


class JkhHelpRequestModel(Base):
    __tablename__ = "jkh_help_requests"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    author_name = Column(String(128), default="Сосед")
    address = Column(String(255), default="Нижневартовск")
    apartment = Column(String(64), nullable=True)
    phone = Column(String(64), nullable=True)
    category = Column(String(64), default="Помощь по дому")
    status = Column(String(32), default="pending")  # pending | claimed | completed
    helper_name = Column(String(128), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))


# Ensure table is created
Base.metadata.create_all(bind=engine)


class HelpRequestCreatePayload(BaseModel):
    title: str
    description: Optional[str] = None
    author_name: Optional[str] = "Сосед"
    address: Optional[str] = "Нижневартовск"
    apartment: Optional[str] = None
    phone: Optional[str] = None
    category: Optional[str] = "Помощь по дому"


class ClaimPayload(BaseModel):
    helper_name: Optional[str] = "Волонтер-сосед"


def _to_dict(req: JkhHelpRequestModel) -> dict[str, Any]:
    return {
        "id": req.id,
        "title": req.title,
        "description": req.description or "",
        "author_name": req.author_name or "Сосед",
        "address": req.address or "Нижневартовск",
        "apartment": req.apartment,
        "phone": req.phone,
        "category": req.category or "Помощь по дому",
        "status": req.status or "pending",
        "helper_name": req.helper_name,
        "created_at": req.created_at.isoformat() if req.created_at else None,
        "updated_at": req.updated_at.isoformat() if req.updated_at else None,
    }


@router.get("/help-requests")
def get_help_requests():
    """List all active neighborhood help requests from DB."""
    db = SessionLocal()
    try:
        rows = db.query(JkhHelpRequestModel).order_by(JkhHelpRequestModel.created_at.desc()).all()
        if not rows:
            # Seed initial sample community requests if empty
            samples = [
                JkhHelpRequestModel(
                    title="Помочь донести сумки с продуктами",
                    description="Пожилая бабушка на 5 этаже без лифта (Мира 28). Нужна помощь занести пакеты.",
                    author_name="Анна Ивановна",
                    address="Мира 28",
                    category="Пожилым",
                    status="pending",
                ),
                JkhHelpRequestModel(
                    title="Прикурить аккумулятор во дворе",
                    description="Замерз авто ВАЗ 2114 на парковке (Интернациональная 19Б). Есть провода.",
                    author_name="Сергей",
                    address="Интернациональная 19Б",
                    category="Авто-помощь",
                    status="claimed",
                    helper_name="Алексей (подъезд 2)",
                ),
                JkhHelpRequestModel(
                    title="Расчистить снег у подножия пандуса",
                    description="Занесло выезд инвалидной коляски (Ленина 15). Снежная лопата есть в подвале.",
                    author_name="Мария",
                    address="Ленина 15",
                    category="Благоустройство",
                    status="completed",
                    helper_name="Игорь В.",
                ),
            ]
            db.add_all(samples)
            db.commit()
            rows = db.query(JkhHelpRequestModel).order_by(JkhHelpRequestModel.created_at.desc()).all()
        return {"ok": True, "requests": [_to_dict(r) for r in rows]}
    finally:
        db.close()


@router.post("/help-requests")
def create_help_request(payload: HelpRequestCreatePayload):
    """Create a new neighborhood help request on the server."""
    db = SessionLocal()
    try:
        req = JkhHelpRequestModel(
            title=payload.title,
            description=payload.description,
            author_name=payload.author_name or "Сосед",
            address=payload.address or "Нижневартовск",
            apartment=payload.apartment,
            phone=payload.phone,
            category=payload.category or "Помощь по дому",
            status="pending",
        )
        db.add(req)
        db.commit()
        db.refresh(req)
        return {"ok": True, "request": _to_dict(req)}
    finally:
        db.close()


@router.post("/help-requests/{request_id}/claim")
def claim_help_request(request_id: int, payload: ClaimPayload | None = None):
    """Mark a help request as claimed/taken in progress (purple/violet stage)."""
    db = SessionLocal()
    try:
        req = db.get(JkhHelpRequestModel, request_id)
        if not req:
            raise HTTPException(status_code=404, detail="Request not found")
        req.status = "claimed"
        req.helper_name = payload.helper_name if payload else "Волонтер-сосед"
        db.commit()
        db.refresh(req)
        return {"ok": True, "request": _to_dict(req)}
    finally:
        db.close()


@router.post("/help-requests/{request_id}/complete")
def complete_help_request(request_id: int):
    """Mark a help request as completed (emerald/green stage)."""
    db = SessionLocal()
    try:
        req = db.get(JkhHelpRequestModel, request_id)
        if not req:
            raise HTTPException(status_code=404, detail="Request not found")
        req.status = "completed"
        db.commit()
        db.refresh(req)
        return {"ok": True, "request": _to_dict(req)}
    finally:
        db.close()
