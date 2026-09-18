# services/Backend/routers/mobile_complaints.py
"""Mobile complaint creation endpoint."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session

from services.data_layer.auth import get_current_user
from services.data_layer.complaint_service import ComplaintService
from services.data_layer.database import get_db
from services.data_layer.models import Report

logger = logging.getLogger(__name__)

router = APIRouter(tags=["mobile-complaints"])
_complaint_limiter = Limiter(key_func=get_remote_address)


class MobileComplaintRequest(BaseModel):
    """Validated schema for mobile complaint submission."""
    title: str = Field(default="", max_length=200)
    description: str | None = Field(default=None, max_length=4000)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    address: str | None = Field(default=None, max_length=300)
    category: str = Field(default="other", max_length=80)
    status: str = Field(default="open", max_length=30)
    user_id: int | None = None


@router.post("/complaints")
@_complaint_limiter.limit("5/minute")
def create_complaint_from_mobile(
    request: Request,
    report: MobileComplaintRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a complaint from the Flutter mobile app."""
    # Use authenticated user ID
    user_id = report.user_id or current_user.get("user_id") or current_user.get("sub")

    try:
        db_report = Report(
            title=report.title,
            description=report.description,
            lat=report.latitude,
            lng=report.longitude,
            address=report.address,
            category=report.category,
            status=report.status,
            user_id=user_id,
        )
        db.add(db_report)
        db.commit()
        db.refresh(db_report)
        res = {
            "id": db_report.id,
            "title": db_report.title,
            "description": db_report.description,
            "latitude": float(db_report.lat) if db_report.lat is not None else None,
            "longitude": float(db_report.lng) if db_report.lng is not None else None,
            "address": db_report.address,
            "category": db_report.category,
            "status": db_report.status,
            "created_at": (
                db_report.created_at.isoformat() if db_report.created_at else None
            ),
        }

        # Reward system
        if user_id:
            reward_msg = ComplaintService.grant_vip_reward_for_report(db, user_id)
            if reward_msg:
                res["reward_message"] = reward_msg

        # Trigger push notification
        try:
            import asyncio
            from services.push_notification_service import trigger_push_for_report
            loop = asyncio.get_event_loop()
            if loop.is_running():
                loop.create_task(trigger_push_for_report(db_report.id))
            else:
                asyncio.run(trigger_push_for_report(db_report.id))
        except Exception as push_exc:
            logger.warning("Failed to trigger push for mobile report #%d: %s", db_report.id, push_exc)

        return res
    except Exception as e:
        db.rollback()
        logger.error("Error creating complaint: %s", e)
        raise HTTPException(status_code=500, detail="Internal server error while creating complaint")
