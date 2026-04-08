from typing import Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from backend.complaint_service import ComplaintService
from backend.database import get_db

router = APIRouter(tags=["complaints"])
complaint_service = ComplaintService()


class ComplaintCreateRequest(BaseModel):
    title: str = Field(default="", max_length=200)
    description: str = Field(default="", max_length=4000)
    address: str | None = Field(default=None, max_length=300)
    latitude: float | None = None
    longitude: float | None = None
    category: str = Field(default="РџСЂРѕС‡РµРµ", max_length=80)
    status: str = Field(default="open", max_length=30)
    user_id: int | None = None
    telegram_channel: str | None = Field(default=None, max_length=200)


class ComplaintStatusUpdateRequest(BaseModel):
    status: str = Field(min_length=1, max_length=30)


@router.get("/complaints/list")
async def get_complaints_list(
    category: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = Query(100, le=100),
    offset: int = Query(0, ge=0),
    user_id: Optional[int] = None,
    telegram_channel: Optional[str] = None,
    db: Session = Depends(get_db),
):
    return complaint_service.get_complaints(
        db=db,
        category=category,
        status=status,
        limit=limit,
        offset=offset,
        user_id=user_id,
        telegram_channel=telegram_channel,
    )


@router.get("/complaints/statistics")
async def get_complaints_statistics(
    db: Session = Depends(get_db),
    user_id: Optional[int] = None,
    telegram_channel: Optional[str] = None,
):
    return complaint_service.get_statistics(
        db=db, user_id=user_id, telegram_channel=telegram_channel
    )


@router.get("/complaints/{complaint_id}")
async def get_complaint_details(complaint_id: int, db: Session = Depends(get_db)):
    return complaint_service.get_complaint_by_id(db, complaint_id)


@router.post("/complaints/create")
async def create_complaint_endpoint(
    request: ComplaintCreateRequest,
    db: Session = Depends(get_db),
):
    result = complaint_service.create_complaint(
        db=db,
        title=request.title,
        description=request.description,
        address=request.address,
        latitude=request.latitude,
        longitude=request.longitude,
        category=request.category,
        status=request.status,
        source="telegram_monitoring",
        user_id=request.user_id,
        telegram_message_id=None,
        telegram_channel=request.telegram_channel,
        nvd_vulnerability_ids=None,
    )

    if not result:
        return {"success": False, "error": "РќРµ СѓРґР°Р»РѕСЃСЊ СЃРѕР·РґР°С‚СЊ Р¶Р°Р»РѕР±Сѓ"}

    res = result.to_dict()
    user_id = request.user_id
    if user_id:
        from datetime import datetime, timedelta

        from backend.models import User, VipSubscription

        user = db.query(User).filter(User.id == user_id).first()
        if user and user.telegram_id:
            sub = db.query(VipSubscription).filter(
                VipSubscription.telegram_id == user.telegram_id
            ).first()
            if not sub:
                sub = VipSubscription(
                    telegram_id=user.telegram_id,
                    tier="free",
                    ai_minutes_total=60 + 30,
                    expires_at=datetime.utcnow() + timedelta(days=365),
                )
                db.add(sub)
            else:
                sub.ai_minutes_total += 30
            db.commit()
            res["reward_message"] = (
                "рџЋЃ Р’Р°Рј РЅР°С‡РёСЃР»РµРЅРѕ 30 РјРёРЅСѓС‚ "
                "РР-РјРѕРЅРёС‚РѕСЂРёРЅРіР° Р·Р° РїРѕРјРѕС‰СЊ РіРѕСЂРѕРґСѓ!"
            )

    return {"success": True, "data": res}


@router.put("/complaints/{complaint_id}/status")
async def update_complaint_status(
    complaint_id: int,
    request: ComplaintStatusUpdateRequest,
    db: Session = Depends(get_db),
):
    return complaint_service.update_complaint_status(
        db=db,
        complaint_id=complaint_id,
        status=request.status,
    )
