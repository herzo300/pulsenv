from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from core.config import TG_BOT_TOKEN
from services.Backend.security import validate_telegram_web_app_data
from services.data_layer.auth import get_current_user
from services.data_layer.complaint_service import ComplaintService
from services.data_layer.database import get_db

router = APIRouter(tags=["complaints"])
complaint_service = ComplaintService()


class ComplaintCreateRequest(BaseModel):
    title: str = Field(default="", max_length=200)
    description: str = Field(default="", max_length=4000)
    address: str | None = Field(default=None, max_length=300)
    latitude: float | None = None
    longitude: float | None = None
    category: str = Field(default="Прочее", max_length=80)
    status: str = Field(default="open", max_length=30)
    user_id: int | None = None
    telegram_channel: str | None = Field(default=None, max_length=200)
    telegram_init_data: str | None = None


class ComplaintStatusUpdateRequest(BaseModel):
    status: str = Field(min_length=1, max_length=30)


@router.get("/complaints/list")
async def get_complaints_list(
    category: str | None = None,
    status: str | None = None,
    limit: int = Query(100, le=100),
    offset: int = Query(0, ge=0),
    user_id: int | None = None,
    telegram_channel: str | None = None,
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
    user_id: int | None = None,
    telegram_channel: str | None = None,
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
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Use authenticated user ID if not provided in request
    user_id = request.user_id or current_user.get("user_id") or current_user.get("sub")

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
        user_id=user_id,
        telegram_message_id=None,
        telegram_channel=request.telegram_channel,
        nvd_vulnerability_ids=None,
    )

    if not result:
        return {
            "success": False,
            "error": "Не удалось создать жалобу",
        }

    res = result.to_dict()
    if user_id:
        if request.telegram_init_data:
            if validate_telegram_web_app_data(request.telegram_init_data, TG_BOT_TOKEN):
                reward_msg = complaint_service.grant_vip_reward_for_report(db, user_id)
                if reward_msg:
                    res["reward_message"] = reward_msg
            else:
                raise HTTPException(status_code=403, detail="Invalid Telegram signature, identity spoofing rejected")

    return {"success": True, "data": res}


@router.put("/complaints/{complaint_id}/status")
async def update_complaint_status(
    complaint_id: int,
    request: ComplaintStatusUpdateRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Only admin/moderator can update status
    user_role = current_user.get("role", "user")
    if user_role not in ("admin", "moderator"):
        raise HTTPException(
            status_code=403,
            detail="Only admins or moderators can update complaint status",
        )
    return complaint_service.update_complaint_status(
        db=db,
        complaint_id=complaint_id,
        status=request.status,
    )
