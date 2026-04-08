"""Runtime data layer backed by the local database and Timeweb storage."""

from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

from backend.database import SessionLocal
from backend.models import Report
from services.geo_service import geoparse, sanitize_address_candidate
from services.local_media_storage import save_image

logger = logging.getLogger(__name__)


def _report_to_dict(report: Report) -> Dict[str, Any]:
    return {
        "id": report.id,
        "title": report.title,
        "summary": report.title,
        "description": report.description,
        "category": report.category,
        "address": report.address,
        "lat": float(report.lat) if report.lat is not None else None,
        "lng": float(report.lng) if report.lng is not None else None,
        "status": report.status,
        "source": report.source,
        "telegram_message_id": report.telegram_message_id,
        "telegram_channel": report.telegram_channel,
        "likes_count": report.likes_count or 0,
        "dislikes_count": report.dislikes_count or 0,
        "supporters": report.supporters or 0,
        "created_at": report.created_at.isoformat() if report.created_at else None,
        "updated_at": report.updated_at.isoformat() if report.updated_at else None,
        "images": [],
    }


def _is_public_source(source: Any) -> bool:
    lower = str(source or "").strip().lower()
    return lower.startswith("vk:") or lower.startswith("tg:") or lower.startswith("telegram:")


def _safe_float(value: Any) -> float | None:
    try:
        if value is None or value == "":
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def _merge_public_text(complaint: Dict[str, Any]) -> str:
    parts: list[str] = []
    for key in ("title", "summary", "description", "text", "location_hints"):
        value = complaint.get(key)
        if value:
            parts.append(str(value))
    return "\n".join(parts).strip()


async def _sanitize_public_geo_payload(complaint: Dict[str, Any]) -> Dict[str, Any]:
    """Normalize public-source address data before it reaches the database."""
    if not _is_public_source(complaint.get("source")):
        return complaint

    payload = dict(complaint)
    payload["_geo_replace_address"] = False
    payload["_geo_replace_coords"] = False

    text = _merge_public_text(payload)
    raw_address = sanitize_address_candidate(payload.get("address"))
    location_hints = sanitize_address_candidate(payload.get("location_hints"))
    lat = _safe_float(payload.get("lat"))
    lng = _safe_float(payload.get("lng"))

    geo = await geoparse(
        text,
        ai_address=raw_address,
        location_hints=location_hints,
    )

    if geo.get("address"):
        payload["address"] = geo["address"]
        payload["lat"] = geo["lat"]
        payload["lng"] = geo["lng"]
        payload["_geo_replace_address"] = True
        payload["_geo_replace_coords"] = True
        payload["geo_source"] = geo.get("geo_source")
        return payload

    # Drop noisy parser garbage instead of persisting it forever.
    if "address" in payload:
        payload["address"] = raw_address
        payload["_geo_replace_address"] = True

    if lat is not None and lng is not None:
        payload["lat"] = lat
        payload["lng"] = lng
        payload["_geo_replace_coords"] = True

    if not raw_address and (lat is None or lng is None):
        payload["address"] = None

    return payload


class RuntimeDataService:
    """Compatibility service API backed by the local database and static storage."""

    @property
    def is_configured(self) -> bool:
        return True

    async def close(self):
        return None

    async def push_complaint(self, complaint: Dict[str, Any]) -> Optional[str]:
        db = SessionLocal()
        try:
            complaint = await _sanitize_public_geo_payload(complaint)

            report: Optional[Report] = None
            raw_id = complaint.get("id")
            if isinstance(raw_id, int):
                report = db.query(Report).filter(Report.id == raw_id).first()

            if report is None:
                tg_msg_id = complaint.get("telegram_message_id")
                tg_channel = complaint.get("telegram_channel")
                if tg_msg_id and tg_channel:
                    report = (
                        db.query(Report)
                        .filter(
                            Report.telegram_message_id == str(tg_msg_id),
                            Report.telegram_channel == str(tg_channel),
                        )
                        .first()
                    )

            if report is None:
                report = Report(
                    title=(complaint.get("title") or complaint.get("summary") or "Сообщение")[:200],
                    description=complaint.get("description") or complaint.get("text") or "",
                    category=complaint.get("category") or "Прочее",
                    address=complaint.get("address"),
                    lat=complaint.get("lat"),
                    lng=complaint.get("lng"),
                    status=complaint.get("status") or "open",
                    source=complaint.get("source") or "runtime",
                    telegram_message_id=(
                        str(complaint.get("telegram_message_id"))
                        if complaint.get("telegram_message_id")
                        else None
                    ),
                    telegram_channel=complaint.get("telegram_channel"),
                )
                db.add(report)
            else:
                report.title = (
                    complaint.get("title")
                    or complaint.get("summary")
                    or report.title
                    or "Сообщение"
                )[:200]
                report.description = complaint.get("description") or complaint.get("text") or report.description
                report.category = complaint.get("category") or report.category or "Прочее"
                if complaint.get("_geo_replace_address"):
                    report.address = complaint.get("address")
                else:
                    report.address = complaint.get("address") or report.address

                if complaint.get("_geo_replace_coords"):
                    report.lat = complaint.get("lat")
                    report.lng = complaint.get("lng")
                else:
                    report.lat = complaint.get("lat") if complaint.get("lat") is not None else report.lat
                    report.lng = complaint.get("lng") if complaint.get("lng") is not None else report.lng

                report.status = complaint.get("status") or report.status or "open"
                report.source = complaint.get("source") or report.source or "runtime"
                if complaint.get("telegram_message_id"):
                    report.telegram_message_id = str(complaint.get("telegram_message_id"))
                if complaint.get("telegram_channel"):
                    report.telegram_channel = complaint.get("telegram_channel")

            db.commit()
            db.refresh(report)
            return str(report.id)
        except Exception as exc:
            db.rollback()
            logger.error("Runtime push_complaint failed: %s", exc)
            return None
        finally:
            db.close()

    async def get_recent_complaints(self, limit: int = 50) -> List[Dict[str, Any]]:
        db = SessionLocal()
        try:
            reports = db.query(Report).order_by(Report.created_at.desc()).limit(limit).all()
            return [_report_to_dict(report) for report in reports]
        finally:
            db.close()

    async def update_complaint_status(self, complaint_id: str, status: str) -> bool:
        db = SessionLocal()
        try:
            report = None
            if str(complaint_id).isdigit():
                report = db.query(Report).filter(Report.id == int(complaint_id)).first()
            if report is None:
                report = db.query(Report).filter(Report.telegram_message_id == str(complaint_id)).first()
            if report is None:
                return False
            report.status = status
            db.commit()
            return True
        except Exception as exc:
            db.rollback()
            logger.error("Runtime update_complaint_status failed: %s", exc)
            return False
        finally:
            db.close()

    async def get_stats(self) -> Dict[str, Any]:
        complaints = await self.get_recent_complaints(limit=1000)
        by_category: Dict[str, int] = {}
        by_status: Dict[str, int] = {}
        for item in complaints:
            by_category[item["category"]] = by_category.get(item["category"], 0) + 1
            by_status[item["status"]] = by_status.get(item["status"], 0) + 1
        return {
            "total": len(complaints),
            "by_category": by_category,
            "by_status": by_status,
        }

    async def save_infographic_data(self, data_type: str, data: Any) -> bool:
        return True

    async def get_infographic_data(self, data_type: Optional[str] = None) -> Dict[str, Any]:
        return {}


_runtime_data_service: Optional[RuntimeDataService] = None


def get_runtime_data_service() -> RuntimeDataService:
    global _runtime_data_service
    if _runtime_data_service is None:
        _runtime_data_service = RuntimeDataService()
    return _runtime_data_service


async def push_complaint(complaint: Dict[str, Any]) -> Optional[str]:
    return await get_runtime_data_service().push_complaint(complaint)


async def get_recent_complaints(limit: int = 50) -> List[Dict[str, Any]]:
    return await get_runtime_data_service().get_recent_complaints(limit)


async def update_complaint_status(complaint_id: str, status: str) -> bool:
    return await get_runtime_data_service().update_complaint_status(complaint_id, status)


async def get_stats() -> Dict[str, Any]:
    return await get_runtime_data_service().get_stats()


def is_runtime_data_configured() -> bool:
    return True


async def upload_file(
    bucket_name: str,
    path: str,
    file_data: bytes,
    content_type: str = "image/jpeg",
) -> Optional[str]:
    filename = path.split("/")[-1]
    return save_image(file_data, filename)


async def upload_image(image_data: bytes, filename: str) -> Optional[str]:
    return save_image(image_data, filename)


__all__ = [
    "RuntimeDataService",
    "get_runtime_data_service",
    "push_complaint",
    "get_recent_complaints",
    "update_complaint_status",
    "get_stats",
    "is_runtime_data_configured",
    "upload_file",
    "upload_image",
]
