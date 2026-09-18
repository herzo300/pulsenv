"""Find nearby duplicate complaints by geo + text overlap."""

from __future__ import annotations

import math
import re
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from services.data_layer.models import Report

_STOPWORDS = {
    "и",
    "в",
    "на",
    "не",
    "что",
    "это",
    "как",
    "для",
    "при",
    "или",
    "уже",
    "нет",
    "the",
    "and",
    "for",
}


def _haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def _tokenize(text: str) -> set[str]:
    tokens = re.findall(r"[A-Za-z0-9]+|[\u0410-\u044F\u0401\u0451]+", text.lower())
    return {t for t in tokens if len(t) > 2 and t not in _STOPWORDS}


def _token_overlap(left: set[str], right: set[str]) -> float:
    if not left or not right:
        return 0.0
    inter = len(left & right)
    union = len(left | right)
    return inter / union if union else 0.0


def find_similar_report(
    db: Session,
    *,
    lat: float,
    lng: float,
    category: str | None = None,
    title: str = "",
    description: str = "",
    address: str = "",
    radius_m: float = 180.0,
    days: int = 14,
) -> dict | None:
    """Return best matching report within radius or None."""
    since = datetime.now(UTC).replace(tzinfo=None) - timedelta(days=days)
    lat_delta = radius_m / 111_000
    lng_delta = radius_m / (111_000 * max(0.5, math.cos(math.radians(lat))))

    query = (
        db.query(Report)
        .filter(
            Report.lat.isnot(None),
            Report.lng.isnot(None),
            Report.created_at >= since,
            Report.lat >= lat - lat_delta,
            Report.lat <= lat + lat_delta,
            Report.lng >= lng - lng_delta,
            Report.lng <= lng + lng_delta,
        )
    )
    if category:
        query = query.filter(Report.category == category)

    reports = query.order_by(Report.created_at.desc()).limit(120).all()

    draft_tokens = _tokenize(f"{title} {description}".strip())
    draft_address = address.strip().lower()
    best_score = 0.0
    best: dict | None = None

    for report in reports:
        r_lat = float(report.lat)
        r_lng = float(report.lng)
        distance_m = _haversine_m(lat, lng, r_lat, r_lng)
        if distance_m > radius_m:
            continue

        report_category = (report.category or "").strip()
        same_category = bool(category and report_category == category)
        report_text = f"{report.title or ''} {report.description or ''}"
        overlap = _token_overlap(draft_tokens, _tokenize(report_text))
        report_address = (report.address or "").lower()
        same_address = bool(
            draft_address
            and report_address
            and draft_address.split(",")[0] in report_address
        )
        distance_score = max(0.0, 1.0 - distance_m / radius_m)
        score = (
            (0.45 if same_category else 0.0)
            + (0.20 if same_address else 0.0)
            + overlap * 0.25
            + distance_score * 0.30
        )
        if score > best_score and (same_category or same_address or overlap >= 0.12):
            best_score = score
            payload = report.to_dict()
            payload["distance_meters"] = round(distance_m)
            payload["similarity_score"] = round(score, 3)
            best = payload

    return best if best_score >= 0.42 else None
