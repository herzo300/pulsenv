"""
Collective Class-Action Petitions Router for Prokuratura & State Housing Inspection (ГЖИ).
"""
import os
import sys
import logging
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import Response
from pydantic import BaseModel
from sqlalchemy.orm import Session

from services.data_layer.database import get_db
from services.data_layer.models import CollectivePetition, PetitionSignature
from services.business.pdf_generator import generate_custom_pdf

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/petitions", tags=["collective-petitions"])


class CreatePetitionRequest(BaseModel):
    title: str
    description: str
    address: str
    category: str = "ЖКХ / Благоустройство"
    lat: Optional[float] = None
    lng: Optional[float] = None
    target_authority: str = "Прокуратура ХМАО-Югры и Служба Жилищного Надзора"
    creator_name: str = "Инициативная группа жителей"


class SignPetitionRequest(BaseModel):
    user_name: str
    flat_number: Optional[str] = "кв. —"
    user_phone_masked: Optional[str] = "+7 (9XX) ***-**-**"


def _seed_petitions_if_empty(db: Session):
    count = db.query(CollectivePetition).count()
    if count == 0:
        p1 = CollectivePetition(
            title="Коллективная претензия в Прокуратуру по систематическому отсутствию ГВС и некачественному теплоснабжению",
            target_authority="Прокуратура ХМАО-Югры и Служба Жилищного Надзора",
            category="ЖКХ",
            address="ул. Героев Самотлора, 20, Нижневартовск",
            lat=60.9412,
            lng=76.6185,
            description="В течение последних 14 дней Управляющая компания и НВТС нарушают допустимые сроки и температурный график подачи горячей воды и отопления в многоквартирном доме.",
            legal_basis="Ст. 161 ЖК РФ, Постановление Правительства РФ № 354 (Приложение 1), СанПиН 2.1.3684-21, ФЗ № 59-ФЗ.",
            signatures_count=7,
            required_signatures=10,
            status="active",
            creator_name="Совет дома ул. Героев Самотлора 20",
        )
        p2 = CollectivePetition(
            title="Коллективное заявление по аварийному состоянию асфальтового покрытия и разрушению тротуаров",
            target_authority="Администрация г. Нижневартовска и ГИБДД ХМАО",
            category="Дороги",
            address="ул. Интернациональная, 14, Нижневартовск",
            lat=60.9482,
            lng=76.5780,
            description="Глубокие ямы (более 12 см) и разрушение бордюрного камня создают угрозу для безопасности пешеходов, автотранспорта и экстренных служб.",
            legal_basis="ГОСТ Р 50597-2017 (Раздел 5.2), Ст. 12 ФЗ № 196-ФЗ «О безопасности дорожного движения».",
            signatures_count=9,
            required_signatures=10,
            status="active",
            creator_name="Жители ул. Интернациональная",
        )
        db.add(p1)
        db.add(p2)
        db.commit()


@router.get("/list")
async def list_petitions(address: Optional[str] = None, db: Session = Depends(get_db)):
    _seed_petitions_if_empty(db)
    query = db.query(CollectivePetition).filter(CollectivePetition.status == "active")
    if address:
        query = query.filter(CollectivePetition.address.ilike(f"%{address}%"))
    petitions = query.order_by(CollectivePetition.id.desc()).all()
    
    res = []
    for p in petitions:
        res.append({
            "id": p.id,
            "title": p.title,
            "target_authority": p.target_authority,
            "category": p.category,
            "address": p.address,
            "lat": p.lat,
            "lng": p.lng,
            "description": p.description,
            "legal_basis": p.legal_basis,
            "signatures_count": p.signatures_count,
            "required_signatures": p.required_signatures,
            "status": p.status,
            "creator_name": p.creator_name,
            "created_at": p.created_at.isoformat() if p.created_at else None,
            "is_ready_for_submission": p.signatures_count >= p.required_signatures,
        })
    return {"success": True, "petitions": res}


@router.post("/create")
async def create_petition(req: CreatePetitionRequest, db: Session = Depends(get_db)):
    legal_basis = (
        "Настоящая петиция составлена в соответствии с Федеральным законом № 59-ФЗ "
        "«О порядке рассмотрения обращений граждан РФ», Жилищным кодексом РФ (ст. 161, 162), "
        "Постановлением Правительства РФ № 354 и ГОСТ Р 50597-2017."
    )
    petition = CollectivePetition(
        title=req.title,
        target_authority=req.target_authority,
        category=req.category,
        address=req.address,
        lat=req.lat,
        lng=req.lng,
        description=req.description,
        legal_basis=legal_basis,
        signatures_count=1,
        required_signatures=10,
        status="active",
        creator_name=req.creator_name,
        created_at=datetime.utcnow(),
    )
    db.add(petition)
    db.commit()
    db.refresh(petition)
    
    # Sign by creator
    sig = PetitionSignature(
        petition_id=petition.id,
        user_name=req.creator_name,
        flat_number="Инициатор",
        signed_at=datetime.utcnow(),
    )
    db.add(sig)
    db.commit()

    return {"success": True, "petition_id": petition.id, "message": "Коллективный иск успешно создан и открыт для цифровых подписей!"}


@router.post("/{petition_id}/sign")
async def sign_petition(petition_id: int, req: SignPetitionRequest, db: Session = Depends(get_db)):
    petition = db.query(CollectivePetition).filter(CollectivePetition.id == petition_id).first()
    if not petition:
        raise HTTPException(status_code=404, detail="Петиция не найдена.")

    sig = PetitionSignature(
        petition_id=petition.id,
        user_name=req.user_name,
        user_phone_masked=req.user_phone_masked,
        flat_number=req.flat_number,
        signed_at=datetime.utcnow(),
    )
    db.add(sig)
    petition.signatures_count += 1
    if petition.signatures_count >= petition.required_signatures:
        petition.status = "ready_for_submission"
    db.commit()

    return {
        "success": True,
        "signatures_count": petition.signatures_count,
        "required_signatures": petition.required_signatures,
        "is_ready": petition.signatures_count >= petition.required_signatures,
        "message": f"Ваша подпись под коллективным иском #{petition_id} принята!",
    }


@router.get("/{petition_id}/pdf")
async def download_petition_pdf(petition_id: int, db: Session = Depends(get_db)):
    petition = db.query(CollectivePetition).filter(CollectivePetition.id == petition_id).first()
    if not petition:
        raise HTTPException(status_code=404, detail="Петиция не найдена.")

    signatures = db.query(PetitionSignature).filter(PetitionSignature.petition_id == petition_id).all()
    sigs_text = "\n".join([f"• {s.user_name} ({s.flat_number or 'житель'}) — подпись зафиксирована {s.signed_at.strftime('%d.%m.%Y %H:%M') if s.signed_at else ''}" for s in signatures])

    pdf_content = (
        f"КОЛЛЕКТИВНОЕ ОБРАЩЕНИЕ ГРАЖДАН (ИИ-КОНСТРУКТОР «ПУЛЬС ГОРОДА»)\n\n"
        f"В: {petition.target_authority}\n"
        f"ОТ: Инициативной группы жителей дома/объекта ({petition.address})\n\n"
        f"ПРЕТЕНЗИЯ / КОЛЛЕКТИВНЫЙ ИСК:\n{petition.title}\n\n"
        f"ОПИСАНИЕ СИТУАЦИИ И НАРУШЕНИЙ:\n{petition.description}\n\n"
        f"ПРАВОВОЕ ОБОСНОВАНИЕ И НОРМАТИВНАЯ БАЗА:\n{petition.legal_basis}\n\n"
        f"СПИСОК ЦИФРОВЫХ ПОДПИСЕЙ ЖИТЕЛЕЙ (Всего подписей: {petition.signatures_count}):\n{sigs_text}\n\n"
        f"Настоящее коллективное обращение сформировано в соответствии с ФЗ-59 РФ и заверено реестром подписей сервиса «Пульс Города»."
    )

    pdf_buf = generate_custom_pdf(
        f"Коллективный Иск #{petition.id} в Прокуратуру",
        pdf_content
    )

    return Response(
        content=pdf_buf.getvalue(),
        media_type="application/pdf",
        headers={"Content-Disposition": f"inline; filename=collective_petition_{petition_id}.pdf"}
    )
