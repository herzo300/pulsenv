from typing import Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from backend.database import get_db
from backend.models import Report

router = APIRouter(prefix="/reports", tags=["reports"])


class ReportCreate(BaseModel):
    title: str
    description: Optional[str] = None
    lat: float
    lng: float
    category: str = "other"


@router.post("/")
def create_report(report: ReportCreate, db: Session = Depends(get_db)):
    db_report = Report(**report.dict())
    db.add(db_report)
    db.commit()
    db.refresh(db_report)
    return db_report
