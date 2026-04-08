# services/Backend/routers/reports.py — API роутер для жалоб/отчётов
import logging

from fastapi import APIRouter, Depends, Query, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from backend.database import get_db
from backend.models import Comment, Report, User

router = APIRouter(tags=["reports"])
logger = logging.getLogger(__name__)


class ReportActionRequest(BaseModel):
    action: str = Field(pattern="^(join|like|dislike)$")


class ReportCommentCreateRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)
    author_name: str = Field(default="Житель", min_length=1, max_length=120)


@router.get("/reports")
async def get_reports(
    request: Request,
    category: str | None = None,
    status: str | None = None,
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    """Список жалоб для API/карты."""
    try:
        query = db.query(Report).order_by(Report.created_at.desc())
        params = request.query_params
        id_filter = params.get("id")
        lat_filter = params.get("lat")
        lng_filter = params.get("lng")
        order = params.get("order", "created_at.desc")

        def _parse_filter(raw: str | None):
            if not raw:
                return None, None
            if "." in raw:
                op, value = raw.split(".", 1)
                return op, value
            return "eq", raw

        if category:
            _, category_value = _parse_filter(category)
            if category_value:
                query = query.filter(Report.category == category_value)
        if status:
            _, status_value = _parse_filter(status)
            if status_value:
                query = query.filter(Report.status == status_value)
        if id_filter:
            _, id_value = _parse_filter(id_filter)
            if id_value and str(id_value).isdigit():
                query = query.filter(Report.id == int(id_value))
        for raw, column in ((lat_filter, Report.lat), (lng_filter, Report.lng)):
            op, value = _parse_filter(raw)
            if value is None:
                continue
            try:
                number = float(value)
            except ValueError:
                continue
            if op == "gte":
                query = query.filter(column >= number)
            elif op == "lte":
                query = query.filter(column <= number)
            elif op == "eq":
                query = query.filter(column == number)

        if order == "id.desc":
            query = query.order_by(Report.id.desc())
        elif order == "id.asc":
            query = query.order_by(Report.id.asc())
        elif order == "created_at.asc":
            query = query.order_by(Report.created_at.asc())
        else:
            query = query.order_by(Report.created_at.desc())
        reports = query.limit(limit).all()
        return [r.to_dict() for r in reports]
    except Exception as exc:  # pragma: no cover - runtime DB dependent
        logger.warning("Failed to load reports list: %s", exc)
        # Keep API stable for mobile clients if primary DB is temporarily unavailable.
        return []


class ReportCreateRequest(BaseModel):
    title: str = Field(default="", max_length=200)
    description: str = Field(default="", max_length=4000)
    address: str | None = Field(default=None, max_length=300)
    category: str = Field(default="Прочее", max_length=80)
    status: str = Field(default="open", max_length=30)
    source: str = Field(default="mobile_app", max_length=80)
    user_id: int | None = None
    likes_count: int = 0
    dislikes_count: int = 0
    supporters: int = 0
    lat: float | None = None
    lng: float | None = None
    latitude: float | None = None
    longitude: float | None = None
    images: list[str] = Field(default_factory=list)


class ReportPatchRequest(BaseModel):
    likes_count: int | None = None
    dislikes_count: int | None = None
    supporters: int | None = None
    status: str | None = Field(default=None, max_length=30)


@router.post("/reports", status_code=201)
async def create_report(
    payload: ReportCreateRequest,
    db: Session = Depends(get_db),
):
    report = Report(
        title=(payload.title or "Обращение").strip()[:200],
        description=(payload.description or "").strip(),
        lat=payload.lat if payload.lat is not None else payload.latitude,
        lng=payload.lng if payload.lng is not None else payload.longitude,
        address=(payload.address or "").strip() or None,
        category=(payload.category or "Прочее").strip(),
        status=(payload.status or "open").strip(),
        source=(payload.source or "mobile_app").strip(),
        user_id=payload.user_id,
        likes_count=max(payload.likes_count, 0),
        dislikes_count=max(payload.dislikes_count, 0),
        supporters=max(payload.supporters, 0),
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report.to_dict()


@router.patch("/reports")
async def patch_report(
    request: Request,
    payload: ReportPatchRequest,
    db: Session = Depends(get_db),
):
    raw_id = request.query_params.get("id", "")
    if not raw_id:
        raise HTTPException(status_code=400, detail="id filter is required")
    _, _, id_value = raw_id.partition(".")
    try:
        target_id = int(id_value or raw_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid id filter") from exc
    report = db.query(Report).filter(Report.id == target_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Not found")

    if payload.likes_count is not None:
        report.likes_count = max(payload.likes_count, 0)
    if payload.dislikes_count is not None:
        report.dislikes_count = max(payload.dislikes_count, 0)
    if payload.supporters is not None:
        report.supporters = max(payload.supporters, 0)
    if payload.status is not None:
        report.status = payload.status

    db.commit()
    db.refresh(report)
    return [report.to_dict()]


@router.get("/reports/{report_id}")
async def get_report(report_id: int, db: Session = Depends(get_db)):
    """Одна жалоба по ID."""
    try:
        report = db.query(Report).filter(Report.id == report_id).first()
    except Exception as exc:  # pragma: no cover - runtime DB dependent
        logger.warning("Failed to load report by id=%s: %s", report_id, exc)
        raise HTTPException(
            status_code=503,
            detail="Reports storage unavailable",
        ) from exc
    if not report:
        raise HTTPException(status_code=404, detail="Not found")
    return report.to_dict()


@router.get("/reports/{report_id}/comments")
async def get_report_comments(report_id: int, db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Not found")

    comments = (
        db.query(Comment)
        .filter(Comment.report_id == report_id)
        .order_by(Comment.created_at.desc())
        .all()
    )
    return [
        {
            "id": comment.id,
            "report_id": comment.report_id,
            "author_name": (
                comment.user.first_name
                if comment.user and comment.user.first_name
                else "Житель"
            ),
            "content": comment.text,
            "created_at": comment.created_at.isoformat() if comment.created_at else None,
        }
        for comment in comments
    ]


@router.post("/reports/{report_id}/comments")
async def add_report_comment(
    report_id: int,
    payload: ReportCommentCreateRequest,
    db: Session = Depends(get_db),
):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Not found")

    author_name = payload.author_name.strip() or "Житель"
    guest_user = User(first_name=author_name)
    db.add(guest_user)
    db.flush()

    comment = Comment(
        report_id=report_id,
        user_id=guest_user.id,
        text=payload.text.strip(),
    )
    db.add(comment)
    db.commit()
    db.refresh(comment)

    return {
        "id": comment.id,
        "report_id": comment.report_id,
        "author_name": author_name,
        "content": comment.text,
        "created_at": comment.created_at.isoformat() if comment.created_at else None,
    }


@router.post("/reports/{report_id}/actions")
async def apply_report_action(
    report_id: int,
    payload: ReportActionRequest,
    db: Session = Depends(get_db),
):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Not found")

    if payload.action == "join":
        report.supporters = (report.supporters or 0) + 1
    elif payload.action == "like":
        report.likes_count = (report.likes_count or 0) + 1
    elif payload.action == "dislike":
        report.dislikes_count = (report.dislikes_count or 0) + 1

    db.commit()
    db.refresh(report)
    return {
        "id": report.id,
        "supporters": report.supporters or 0,
        "likes_count": report.likes_count or 0,
        "dislikes_count": report.dislikes_count or 0,
    }
