"""SOS location sharing router — zero-knowledge encrypted coordinates for VIP users."""
from __future__ import annotations

import hashlib
import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from services.data_layer.database import get_db
from services.data_layer.models import User, UserLocationShare
from services.data_layer.auth import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/sos", tags=["sos"])


class ShareLocationRequest(BaseModel):
    encrypted_latitude: str
    encrypted_longitude: str


class InviteTrackerRequest(BaseModel):
    receiver_telegram_id: int
    passcode: str  # Password or barcode value shared between users


def hash_passcode(passcode: str) -> str:
    """Hash passcode using SHA-256."""
    return hashlib.sha256(passcode.encode("utf-8")).hexdigest()


@router.post("/share")
async def share_location(
    req: ShareLocationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Update encrypted live location.
    Coordinates are encrypted on client-side to prevent admin access.
    """
    is_vip = bool(
        current_user.digest_subscription_until
        and current_user.digest_subscription_until > datetime.utcnow()
    )
    if not is_vip:
        raise HTTPException(
            status_code=403,
            detail="Функция живого SOS-шеринга координат доступна только VIP-подписчикам!",
        )

    if not current_user.telegram_id:
        raise HTTPException(
            status_code=400,
            detail="У вашего аккаунта не привязан Telegram ID.",
        )

    # Find active location shares
    shares = (
        db.query(UserLocationShare)
        .filter(
            UserLocationShare.sharer_telegram_id == current_user.telegram_id,
            UserLocationShare.is_active == True,
        )
        .all()
    )

    if not shares:
        return {
            "success": True,
            "message": "Местоположение получено, но ни с кем не шерится. Настройте семейный доступ.",
            "shares_updated": 0,
        }

    for share in shares:
        share.encrypted_latitude = req.encrypted_latitude
        share.encrypted_longitude = req.encrypted_longitude
        share.updated_at = datetime.utcnow()

    db.commit()
    return {
        "success": True,
        "shares_updated": len(shares),
    }


@router.post("/invite")
async def invite_tracker(
    req: InviteTrackerRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Invite family member to track your coordinates.
    Requires a passcode/barcode shared with the receiver.
    """
    is_vip = bool(
        current_user.digest_subscription_until
        and current_user.digest_subscription_until > datetime.utcnow()
    )
    if not is_vip:
        raise HTTPException(
            status_code=403,
            detail="Настройка SOS-кругов доверия доступна только VIP-подписчикам!",
        )

    if not current_user.telegram_id:
        raise HTTPException(
            status_code=400,
            detail="У вашего аккаунта не привязан Telegram ID.",
        )

    if req.receiver_telegram_id == current_user.telegram_id:
        raise HTTPException(
            status_code=400,
            detail="Вы не можете делиться местоположением с самим собой.",
        )

    pass_hash = hash_passcode(req.passcode)

    # Check existing share
    existing = (
        db.query(UserLocationShare)
        .filter(
            UserLocationShare.sharer_telegram_id == current_user.telegram_id,
            UserLocationShare.receiver_telegram_id == req.receiver_telegram_id,
        )
        .first()
    )

    if existing:
        existing.is_active = True
        existing.passcode_hash = pass_hash
        existing.updated_at = datetime.utcnow()
    else:
        new_share = UserLocationShare(
            sharer_telegram_id=current_user.telegram_id,
            receiver_telegram_id=req.receiver_telegram_id,
            passcode_hash=pass_hash,
            is_active=True,
        )
        db.add(new_share)

    db.commit()
    return {
        "success": True,
        "message": f"Доступ к вашим зашифрованным координатам открыт для {req.receiver_telegram_id}. Передайте ему ваш пароль или штрих-код.",
    }


@router.get("/live-locations")
async def get_live_locations(
    passcode: str = Query(..., description="Passcode shared by the family member"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Get live location coordinate ciphertexts of family members.
    Requires the shared passcode. The backend validates the passcode hash,
    and returns the encrypted coordinates (zero-knowledge for admins).
    """
    is_vip = bool(
        current_user.digest_subscription_until
        and current_user.digest_subscription_until > datetime.utcnow()
    )
    if not is_vip:
        raise HTTPException(
            status_code=403,
            detail="Просмотр геолокации близких доступен только VIP-подписчикам!",
        )

    if not current_user.telegram_id:
        raise HTTPException(
            status_code=400,
            detail="У вашего аккаунта не привязан Telegram ID.",
        )

    p_hash = hash_passcode(passcode)

    # Find shares where current_user is the receiver and passcode matches the hash
    shares = (
        db.query(UserLocationShare)
        .filter(
            UserLocationShare.receiver_telegram_id == current_user.telegram_id,
            UserLocationShare.is_active == True,
            UserLocationShare.passcode_hash == p_hash,
            UserLocationShare.encrypted_latitude != None,
            UserLocationShare.encrypted_longitude != None,
        )
        .all()
    )

    results = []
    for s in shares:
        sharer = db.query(User).filter(User.telegram_id == s.sharer_telegram_id).first()
        results.append(
            {
                "telegram_id": s.sharer_telegram_id,
                "first_name": sharer.first_name if sharer else "Пользователь",
                "last_name": sharer.last_name if sharer else "",
                "username": sharer.username if sharer else None,
                "encrypted_latitude": s.encrypted_latitude,
                "encrypted_longitude": s.encrypted_longitude,
                "updated_at": s.updated_at.isoformat() if s.updated_at else None,
            }
        )

    if not results:
        raise HTTPException(
            status_code=403,
            detail="Неверный пароль/штрих-код или доступ к координатам не открыт.",
        )

    return {"success": True, "locations": results}
