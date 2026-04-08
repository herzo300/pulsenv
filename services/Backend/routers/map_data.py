"""Map feed endpoints: public reports, geocoded markers, and city events."""

from __future__ import annotations

import asyncio
import os
import re
from datetime import date, datetime, timedelta
from typing import Any
from urllib.parse import urljoin

import httpx
from bs4 import BeautifulSoup
from fastapi import APIRouter, Query

from backend.database import SessionLocal
from backend.models import Report
from services.geo_service import geoparse, sanitize_address_candidate
from services.zai_service import build_marker_summary, make_marker_summary

router = APIRouter(tags=["map-data"])

AFISHA_URL = "https://www.n-vartovsk.ru/afisha/"

VENUE_COORDS: dict[str, dict[str, Any]] = {
    "дворец искусств": {
        "name": "Дворец искусств",
        "lat": 60.9404877,
        "lng": 76.5587701,
        "address": "ул. Ленина, 7, Нижневартовск",
    },
    "площади дворца искусств": {
        "name": "Площадь Дворца искусств",
        "lat": 60.9404877,
        "lng": 76.5587701,
        "address": "ул. Ленина, 7, Нижневартовск",
    },
    "площадь нефтяников": {
        "name": "Площадь Нефтяников",
        "lat": 60.9405,
        "lng": 76.5450,
        "address": "Площадь Нефтяников, Нижневартовск",
    },
    "green park": {
        "name": "МФК Green Park",
        "lat": 60.9384798,
        "lng": 76.5558084,
        "address": "ул. Ленина, 8, Нижневартовск",
    },
    "ленина, 8": {
        "name": "МФК Green Park",
        "lat": 60.9384798,
        "lng": 76.5558084,
        "address": "ул. Ленина, 8, Нижневартовск",
    },
}

EVENT_DATE_RE = re.compile(r"(?P<date>\d{2}\.\d{2}\.\d{4})(?:\s+(?P<time>\d{2}:\d{2}))?")
MAP_REPORTS_TIMEOUT_SECONDS = 12.0
MAP_EVENTS_TIMEOUT_SECONDS = 12.0
MAP_FEED_ENABLE_GEOPARSE = (os.getenv("MAP_FEED_ENABLE_GEOPARSE") or "1").strip() != "0"
MAP_PER_REPORT_TIMEOUT_SECONDS = float(os.getenv("MAP_PER_REPORT_TIMEOUT_SECONDS", "2.5"))
MAP_REPORT_MAX_AGE_DAYS = int(os.getenv("MAP_REPORT_MAX_AGE_DAYS", "120"))

CITY_PROBLEM_CATEGORIES = {
    "Дороги",
    "ЖКХ",
    "Освещение",
    "Транспорт",
    "Экология",
    "Безопасность",
    "Снег/Наледь",
    "Медицина",
    "Здравоохранение",
    "Образование",
    "Парковки",
    "Строительство",
    "Благоустройство",
}

CITY_PROBLEM_KEYWORDS = (
    "авар",
    "яма",
    "дорог",
    "тротуар",
    "двор",
    "подъезд",
    "крыша",
    "лифт",
    "свет",
    "освещ",
    "отключ",
    "порыв",
    "прорыв",
    "утеч",
    "канализ",
    "мусор",
    "свалк",
    "парк",
    "сквер",
    "парковк",
    "снег",
    "налед",
    "лед",
    "дым",
    "вон",
    "запах",
    "шум",
    "пожар",
    "опасн",
    "светофор",
    "дтп",
    "ремонт",
    "строитель",
    "эколог",
)

NON_CITY_PROBLEM_KEYWORDS = (
    "мероприят",
    "афиша",
    "концерт",
    "спектак",
    "фестиваль",
    "мастер-класс",
    "лекци",
    "приглаша",
    "скидк",
    "акци",
    "розыгрыш",
    "ваканси",
    "продам",
    "сдам",
    "аренда",
    "реклама",
)


def _now_local() -> datetime:
    return datetime.now()


def _parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _report_text(report: dict[str, Any]) -> str:
    return " ".join(
        str(report.get(field) or "").strip().lower()
        for field in ("title", "summary", "description", "address", "category")
    )


def _normalize_report_address(report: dict[str, Any]) -> str | None:
    normalized = sanitize_address_candidate(report.get("address"))
    if normalized:
        report["address"] = normalized
    return normalized


def _marker_text_signature(value: Any) -> str:
    cleaned = make_marker_summary(str(value or ""), max_len=120).lower()
    cleaned = re.sub(r"[^a-zа-яё0-9\s]", " ", cleaned, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", cleaned).strip()


def _marker_coords_bucket(lat: Any, lng: Any) -> tuple[float, float] | None:
    if lat is None or lng is None:
        return None
    try:
        return (round(float(lat), 3), round(float(lng), 3))
    except (TypeError, ValueError):
        return None


def _dedupe_marker_records(markers: list[dict[str, Any]]) -> list[dict[str, Any]]:
    unique: list[dict[str, Any]] = []
    seen: set[tuple[Any, ...]] = set()

    for marker in markers:
        category = _normalize_category(marker.get("category"))
        address = sanitize_address_candidate(marker.get("address"))
        summary = _marker_text_signature(marker.get("summary") or marker.get("description"))
        coords = _marker_coords_bucket(marker.get("lat"), marker.get("lng"))

        candidate_keys: list[tuple[Any, ...]] = []
        if address and summary:
            candidate_keys.append((category, address, summary))
        if coords and summary:
            candidate_keys.append((category, coords, summary))
        if not candidate_keys and address:
            candidate_keys.append((category, address))
        if not candidate_keys and coords:
            candidate_keys.append((category, coords))

        if candidate_keys and any(key in seen for key in candidate_keys):
            continue

        unique.append(marker)
        for key in candidate_keys:
            seen.add(key)

    return unique


def _is_recent_report(report: dict[str, Any]) -> bool:
    raw = report.get("created_at") or report.get("updated_at")
    parsed = _parse_dt(raw if isinstance(raw, str) else None)
    if parsed is None:
        return True
    if parsed.tzinfo is not None:
        parsed = parsed.replace(tzinfo=None)
    return parsed >= _now_local() - timedelta(days=MAP_REPORT_MAX_AGE_DAYS)


def _is_city_problem(report: dict[str, Any]) -> bool:
    source = str(report.get("source") or "").strip().lower()
    category = _normalize_category(report.get("category"))
    text = _report_text(report)

    if source == "official:afisha" or category == "Мероприятие":
        return False
    if any(keyword in text for keyword in NON_CITY_PROBLEM_KEYWORDS):
        return False
    if category in CITY_PROBLEM_CATEGORIES:
        return True
    return any(keyword in text for keyword in CITY_PROBLEM_KEYWORDS)


def _cleanup_reason(report: dict[str, Any]) -> str | None:
    if not _is_recent_report(report):
        return "stale"
    if not _is_city_problem(report):
        return "not_city_problem"
    if _normalize_report_address(report) is None:
        return "invalid_address"
    return None


def _normalize_category(value: Any) -> str:
    category = str(value or "").strip()
    return category or "Прочее"


def _source_label(source: str) -> str:
    lower = (source or "").lower()
    if lower.startswith("vk:"):
        return f"VK · {source.split(':', 1)[1]}"
    if lower.startswith("tg:") or lower.startswith("telegram:"):
        return f"Telegram · {source.split(':', 1)[1]}"
    return source or "Источник не указан"


def _is_public_source(source: str) -> bool:
    lower = (source or "").lower()
    return lower.startswith("vk:") or lower.startswith("tg:") or lower.startswith("telegram:")


def _pick_venue(text: str) -> dict[str, Any] | None:
    haystack = text.lower()
    for key, venue in VENUE_COORDS.items():
        if key in haystack:
            return venue
    return None


def _extract_event_title(text: str) -> str:
    cleaned = EVENT_DATE_RE.sub("", text, count=1).strip(" -")
    first_sentence = re.split(r"(?<=[.!?])\s+", cleaned, maxsplit=1)[0].strip()
    return (first_sentence or cleaned)[:180]


def _extract_event_datetime(text: str) -> datetime | None:
    match = EVENT_DATE_RE.search(text)
    if not match:
        return None
    raw_date = match.group("date")
    raw_time = match.group("time") or "12:00"
    try:
        return datetime.strptime(f"{raw_date} {raw_time}", "%d.%m.%Y %H:%M")
    except ValueError:
        return None


def _persist_report_geo(report_id: int, lat: float, lng: float, address: str | None) -> None:
    db = SessionLocal()
    try:
        report = db.query(Report).filter(Report.id == report_id).first()
        if not report:
            return
        changed = False
        if report.lat is None:
            report.lat = lat
            changed = True
        if report.lng is None:
            report.lng = lng
            changed = True
        if address and (not report.address or report.address != address):
            report.address = address
            changed = True
        if changed:
            db.commit()
    except Exception:
        db.rollback()
    finally:
        db.close()


async def _fetch_local_reports(limit: int, *, public_only: bool = False) -> list[dict[str, Any]]:
    db = SessionLocal()
    try:
        query = db.query(Report)
        if public_only:
            query = query.filter(
                (Report.source.like("vk:%"))
                | (Report.source.like("tg:%"))
                | (Report.source.like("telegram:%"))
            )

        reports = query.order_by(Report.created_at.desc()).limit(limit).all()
        return [
            {
                "id": report.id,
                "title": report.title,
                "summary": report.title,
                "description": report.description,
                "address": report.address,
                "lat": report.lat,
                "lng": report.lng,
                "category": report.category,
                "status": report.status,
                "source": report.source,
                "created_at": report.created_at.isoformat() if report.created_at else None,
                "updated_at": report.updated_at.isoformat() if report.updated_at else None,
                "likes_count": report.likes_count or 0,
                "dislikes_count": report.dislikes_count or 0,
                "supporters": report.supporters or 0,
                "images": [],
                "post_link": None,
            }
            for report in reports
        ]
    finally:
        db.close()


async def _enrich_report(report: dict[str, Any]) -> dict[str, Any] | None:
    lat = report.get("lat")
    lng = report.get("lng")
    source = str(report.get("source") or "")
    normalized_address = _normalize_report_address(report)
    if (lat is None or lng is None) and MAP_FEED_ENABLE_GEOPARSE and _is_public_source(source):
        text = "\n".join(filter(None, [report.get("title"), report.get("description")]))
        geo = await geoparse(
            text=text,
            ai_address=normalized_address,
            location_hints=normalized_address,
        )
        lat = geo.get("lat")
        lng = geo.get("lng")
        if geo.get("address"):
            report["address"] = geo["address"]
            normalized_address = _normalize_report_address(report)
        if lat is not None and lng is not None and report.get("id") is not None:
            await asyncio.to_thread(
                _persist_report_geo,
                int(report["id"]),
                float(lat),
                float(lng),
                normalized_address,
            )

    if lat is None or lng is None:
        return None
    if _cleanup_reason(report) is not None:
        return None

    normalized = {
        "id": f"report-{report.get('id')}",
        "origin_id": report.get("id"),
        "summary": report.get("title") or report.get("summary") or "Сообщение",
        "description": report.get("description") or "",
        "lat": float(lat),
        "lng": float(lng),
        "address": report.get("address"),
        "category": _normalize_category(report.get("category")),
        "status": report.get("status") or "open",
        "source": source,
        "source_label": _source_label(source),
        "source_kind": "public" if _is_public_source(source) else "report",
        "source_table": "reports",
        "created_at": report.get("created_at"),
        "updated_at": report.get("updated_at"),
        "images": report.get("images") or [],
        "likes_count": report.get("likes_count") or 0,
        "dislikes_count": report.get("dislikes_count") or 0,
        "supporters": report.get("supporters") or 0,
        "link": report.get("post_link") or None,
    }
    return normalized


async def _load_public_markers(limit: int) -> list[dict[str, Any]]:
    candidate_limit = max(limit * 2, 180)
    public_candidate_limit = max(limit, 120)

    recent_reports, recent_public_reports = await asyncio.gather(
        _fetch_local_reports(candidate_limit),
        _fetch_local_reports(public_candidate_limit, public_only=True),
    )

    merged_reports: list[dict[str, Any]] = []
    seen_ids: set[int] = set()

    for report in [*recent_public_reports, *recent_reports]:
        report_id = int(report.get("id") or 0)
        if report_id in seen_ids:
            continue
        seen_ids.add(report_id)
        merged_reports.append(report)

    reports_with_coords = [
        report
        for report in merged_reports
        if report.get("lat") is not None and report.get("lng") is not None
    ]
    reports_without_coords = [
        report
        for report in merged_reports
        if report.get("lat") is None or report.get("lng") is None
    ]

    # Prioritize already-geocoded markers and only spend bounded time on missing coordinates.
    pending_quota = min(max(limit // 3, 8), 24)
    prioritized_reports = [*reports_with_coords, *reports_without_coords[:pending_quota]]

    tasks = [
        asyncio.wait_for(
            _enrich_report(report),
            timeout=MAP_PER_REPORT_TIMEOUT_SECONDS,
        )
        for report in prioritized_reports
    ]
    enriched = await asyncio.gather(*tasks, return_exceptions=True)
    markers = [
        item
        for item in enriched
        if isinstance(item, dict) and item
    ]
    public_markers = [item for item in markers if item.get("source_kind") == "public"]
    other_markers = [item for item in markers if item.get("source_kind") != "public"]
    public_markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    other_markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)

    public_quota = min(max(limit // 4, 12), 40)
    selected = public_markers[:public_quota]
    remaining = max(limit - len(selected), 0)
    selected.extend(other_markers[:remaining])
    selected.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    return selected


async def _enrich_report(report: dict[str, Any]) -> dict[str, Any] | None:
    lat = report.get("lat")
    lng = report.get("lng")
    source = str(report.get("source") or "")
    normalized_address = _normalize_report_address(report)
    if (lat is None or lng is None) and MAP_FEED_ENABLE_GEOPARSE and _is_public_source(source):
        text = "\n".join(filter(None, [report.get("title"), report.get("description")]))
        geo = await geoparse(
            text=text,
            ai_address=normalized_address,
            location_hints=normalized_address,
        )
        lat = geo.get("lat")
        lng = geo.get("lng")
        if geo.get("address"):
            report["address"] = geo["address"]
            normalized_address = _normalize_report_address(report)
        if lat is not None and lng is not None and report.get("id") is not None:
            await asyncio.to_thread(
                _persist_report_geo,
                int(report["id"]),
                float(lat),
                float(lng),
                normalized_address,
            )

    if lat is None or lng is None:
        return None
    if _cleanup_reason(report) is not None:
        return None

    marker_summary = build_marker_summary(
        report.get("title") or report.get("summary"),
        report.get("description"),
        max_len=120,
    ) or "Сообщение"

    return {
        "id": f"report-{report.get('id')}",
        "origin_id": report.get("id"),
        "summary": marker_summary,
        "description": marker_summary,
        "lat": float(lat),
        "lng": float(lng),
        "address": report.get("address"),
        "category": _normalize_category(report.get("category")),
        "status": report.get("status") or "open",
        "source": source,
        "source_label": _source_label(source),
        "source_kind": "public" if _is_public_source(source) else "report",
        "source_table": "reports",
        "created_at": report.get("created_at"),
        "updated_at": report.get("updated_at"),
        "images": report.get("images") or [],
        "likes_count": report.get("likes_count") or 0,
        "dislikes_count": report.get("dislikes_count") or 0,
        "supporters": report.get("supporters") or 0,
        "link": report.get("post_link") or None,
    }


async def _load_public_markers(limit: int) -> list[dict[str, Any]]:
    candidate_limit = max(limit * 2, 180)
    public_candidate_limit = max(limit, 120)

    recent_reports, recent_public_reports = await asyncio.gather(
        _fetch_local_reports(candidate_limit),
        _fetch_local_reports(public_candidate_limit, public_only=True),
    )

    merged_reports: list[dict[str, Any]] = []
    seen_ids: set[int] = set()

    for report in [*recent_public_reports, *recent_reports]:
        report_id = int(report.get("id") or 0)
        if report_id in seen_ids:
            continue
        seen_ids.add(report_id)
        merged_reports.append(report)

    reports_with_coords = [
        report
        for report in merged_reports
        if report.get("lat") is not None and report.get("lng") is not None
    ]
    reports_without_coords = [
        report
        for report in merged_reports
        if report.get("lat") is None or report.get("lng") is None
    ]

    pending_quota = min(max(limit // 3, 8), 24)
    prioritized_reports = [*reports_with_coords, *reports_without_coords[:pending_quota]]

    tasks = [
        asyncio.wait_for(
            _enrich_report(report),
            timeout=MAP_PER_REPORT_TIMEOUT_SECONDS,
        )
        for report in prioritized_reports
    ]
    enriched = await asyncio.gather(*tasks, return_exceptions=True)
    markers = [item for item in enriched if isinstance(item, dict) and item]

    public_markers = [item for item in markers if item.get("source_kind") == "public"]
    other_markers = [item for item in markers if item.get("source_kind") != "public"]
    public_markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    other_markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    public_markers = _dedupe_marker_records(public_markers)
    other_markers = _dedupe_marker_records(other_markers)

    public_quota = min(max(limit // 4, 12), 40)
    selected = public_markers[:public_quota]
    remaining = max(limit - len(selected), 0)
    selected.extend(other_markers[:remaining])
    selected.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    return selected


async def _load_city_events() -> dict[str, list[dict[str, Any]]]:
    """Load city events for TODAY only. Events that have already ended are excluded."""
    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        response = await client.get(AFISHA_URL)
        response.raise_for_status()
    soup = BeautifulSoup(response.text, "html.parser")
    cards = soup.select(".single-news")

    now = _now_local()
    today = now.date()
    today_events: list[dict[str, Any]] = []

    for index, card in enumerate(cards, start=1):
        text = card.get_text(" ", strip=True)
        event_dt = _extract_event_datetime(text)
        if not event_dt:
            continue

        event_date = event_dt.date()
        # Only today's events
        if event_date != today:
            continue

        # Skip events that have already passed (assume ~2h duration)
        event_end = event_dt + timedelta(hours=2)
        if event_end < now:
            continue

        venue = _pick_venue(text)
        if not venue:
            continue

        link = None
        anchor = card.find("a", href=True)
        if anchor:
            link = urljoin(AFISHA_URL, anchor["href"])

        event = {
            "id": f"event-{event_date.isoformat()}-{index}",
            "summary": _extract_event_title(text),
            "description": text,
            "lat": venue["lat"],
            "lng": venue["lng"],
            "address": venue["address"],
            "venue": venue["name"],
            "category": "Мероприятие",
            "status": "open",
            "source": "official:afisha",
            "source_label": "Официальная афиша",
            "source_kind": "event",
            "source_table": "events",
            "created_at": event_dt.isoformat(),
            "updated_at": event_dt.isoformat(),
            "images": [],
            "likes_count": 0,
            "dislikes_count": 0,
            "supporters": 0,
            "link": link,
        }
        today_events.append(event)

    today_events.sort(key=lambda item: item["created_at"])
    return {"today": today_events}


@router.get("/map/feed")
async def get_map_feed(
    limit: int = Query(250, ge=50, le=500),
):
    reports_task = asyncio.create_task(
        asyncio.wait_for(
            _load_public_markers(limit=limit),
            timeout=MAP_REPORTS_TIMEOUT_SECONDS,
        )
    )
    events_task = asyncio.create_task(
        asyncio.wait_for(
            _load_city_events(),
            timeout=MAP_EVENTS_TIMEOUT_SECONDS,
        )
    )
    reports_result, events_result = await asyncio.gather(
        reports_task,
        events_task,
        return_exceptions=True,
    )

    reports = reports_result if isinstance(reports_result, list) else []
    events = (
        events_result
        if isinstance(events_result, dict)
        else {"today": []}
    )

    markers = [*reports, *events["today"]]
    markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    return {
        "success": True,
        "generated_at": _now_local().isoformat(),
        "counts": {
            "markers": len(markers),
            "public_reports": len(reports),
            "events_today": len(events["today"]),
        },
        "markers": markers,
        "reports": reports,
        "events": events,
    }
