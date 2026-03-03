# services/Backend/routers/complaints.py
from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from backend.database import get_db
from backend.complaint_service import ComplaintService

router = APIRouter(tags=["complaints"])
complaint_service = ComplaintService()


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
async def create_complaint_endpoint(request: dict, db: Session = Depends(get_db)):
    result = complaint_service.create_complaint(
        db=db,
        title=request.get("title", ""),
        description=request.get("description", ""),
        latitude=request.get("latitude"),
        longitude=request.get("longitude"),
        category=request.get("category", "Прочее"),
        status=request.get("status", "open"),
        source="telegram_monitoring",
        user_id=request.get("user_id"),
        telegram_message_id=None,
        telegram_channel=request.get("telegram_channel"),
        nvd_vulnerability_ids=None,
    )
    return result


@router.put("/complaints/{complaint_id}/status")
async def update_complaint_status(
    complaint_id: int, request: dict, db: Session = Depends(get_db)
):
    return complaint_service.update_complaint_status(
        db=db, complaint_id=complaint_id, status=request.get("status", "")
    )
