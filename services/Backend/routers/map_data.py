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

from services.geo_service import geoparse

router = APIRouter(tags=["map-data"])

SUPABASE_URL = (os.getenv("SUPABASE_URL") or "").rstrip("/")
SUPABASE_KEY = (
    os.getenv("SUPABASE_ANON_KEY")
    or os.getenv("SUPABASE_ANON_API_KEY")
    or ""
)
SUPABASE_REPORTS_URL = f"{SUPABASE_URL}/rest/v1/reports" if SUPABASE_URL else ""
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
MAP_FEED_ENABLE_GEOPARSE = (os.getenv("MAP_FEED_ENABLE_GEOPARSE") or "0").strip() == "1"


def _now_local() -> datetime:
    return datetime.now()


def _parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
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


async def _fetch_supabase_reports(limit: int) -> list[dict[str, Any]]:
    if not SUPABASE_REPORTS_URL or not SUPABASE_KEY:
        return []
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }
    params = {
        "select": "*",
        "order": "created_at.desc",
        "limit": str(limit),
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.get(SUPABASE_REPORTS_URL, headers=headers, params=params)
        response.raise_for_status()
        payload = response.json()
    return payload if isinstance(payload, list) else []


async def _enrich_report(report: dict[str, Any]) -> dict[str, Any] | None:
    lat = report.get("lat")
    lng = report.get("lng")
    if (lat is None or lng is None) and MAP_FEED_ENABLE_GEOPARSE:
        text = "\n".join(filter(None, [report.get("title"), report.get("description")]))
        geo = await geoparse(text=text, ai_address=report.get("address"), location_hints=report.get("address"))
        lat = geo.get("lat")
        lng = geo.get("lng")
        if not report.get("address") and geo.get("address"):
            report["address"] = geo["address"]

    if lat is None or lng is None:
        return None

    source = str(report.get("source") or "")
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
    reports = await _fetch_supabase_reports(limit)
    tasks = [_enrich_report(report) for report in reports]
    enriched = await asyncio.gather(*tasks)
    markers = [item for item in enriched if item]
    markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    return markers


async def _load_city_events(days: int) -> dict[str, list[dict[str, Any]]]:
    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        response = await client.get(AFISHA_URL)
        response.raise_for_status()
    soup = BeautifulSoup(response.text, "html.parser")
    cards = soup.select(".single-news")

    today = _now_local().date()
    week_end = today + timedelta(days=max(days, 1) - 1)
    today_events: list[dict[str, Any]] = []
    week_events: list[dict[str, Any]] = []

    for index, card in enumerate(cards, start=1):
        text = card.get_text(" ", strip=True)
        event_dt = _extract_event_datetime(text)
        if not event_dt:
            continue

        event_date = event_dt.date()
        if event_date < today or event_date > week_end:
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

        if event_date == today:
            today_events.append(event)
        week_events.append(event)

    week_events.sort(key=lambda item: item["created_at"])
    today_events.sort(key=lambda item: item["created_at"])
    return {"today": today_events, "week": week_events}


@router.get("/map/feed")
async def get_map_feed(
    limit: int = Query(250, ge=50, le=500),
    event_days: int = Query(7, ge=1, le=7),
):
    reports_task = asyncio.create_task(
        asyncio.wait_for(
            _load_public_markers(limit=limit),
            timeout=MAP_REPORTS_TIMEOUT_SECONDS,
        )
    )
    events_task = asyncio.create_task(
        asyncio.wait_for(
            _load_city_events(days=event_days),
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
        else {"today": [], "week": []}
    )

    markers = [*reports, *events["week"]]
    markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    return {
        "success": True,
        "generated_at": _now_local().isoformat(),
        "counts": {
            "markers": len(markers),
            "public_reports": len(reports),
            "events_today": len(events["today"]),
            "events_week": len(events["week"]),
        },
        "markers": markers,
        "reports": reports,
        "events": events,
    }
