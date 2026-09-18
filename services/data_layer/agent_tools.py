from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

from sqlalchemy.orm import Session

from services.data_layer.models import Report

logger = logging.getLogger(__name__)

ALLOWED_TOOLS = {"report_lookup", "opendata_lookup", "phone_osint_lookup"}

_OPENDATA_PATH = Path(__file__).resolve().parent.parent.parent / "opendata_full.json"
_opendata_cache: dict | None = None


def run_tool(name: str, tool_input: dict[str, Any], db: Session) -> dict[str, Any]:
    if name not in ALLOWED_TOOLS:
        raise ValueError(f"Unsupported tool: {name}")
    if name == "report_lookup":
        return _report_lookup(db=db, tool_input=tool_input)
    if name == "opendata_lookup":
        return _opendata_lookup(tool_input=tool_input)
    if name == "phone_osint_lookup":
        return _phone_osint_lookup(tool_input=tool_input)
    raise ValueError(f"Unsupported tool: {name}")



def _report_lookup(*, db: Session, tool_input: dict[str, Any]) -> dict[str, Any]:
    limit = int(tool_input.get("limit") or 5)
    limit = max(1, min(limit, 20))
    query = db.query(Report).order_by(Report.created_at.desc())
    category = str(tool_input.get("category") or "").strip()
    status = str(tool_input.get("status") or "").strip()
    if category:
        query = query.filter(Report.category == category)
    if status:
        query = query.filter(Report.status == status)
    reports = query.limit(limit).all()
    return {
        "count": len(reports),
        "reports": [report.to_dict() for report in reports],
    }


def _load_opendata() -> dict:
    """Load and cache opendata_full.json."""
    global _opendata_cache
    if _opendata_cache is not None:
        return _opendata_cache
    if not _OPENDATA_PATH.is_file():
        return {}
    try:
        _opendata_cache = json.loads(
            _OPENDATA_PATH.read_text(encoding="utf-8")
        )
        return _opendata_cache
    except (json.JSONDecodeError, OSError) as exc:
        logger.warning("Failed to load opendata: %s", exc)
        return {}


def _opendata_lookup(*, tool_input: dict) -> dict:
    """Search open data by dataset key or keyword.

    Accepts:
        dataset: exact dataset key (e.g. 'busroute', 'averagesalary')
        keyword: text search across dataset titles
        limit: max rows to return from matched dataset (default 5)
    """
    data = _load_opendata()
    if not data:
        return {"error": "opendata not available", "datasets": []}

    dataset_key = str(tool_input.get("dataset") or "").strip().lower()
    keyword = str(tool_input.get("keyword") or "").strip().lower()
    limit = max(1, min(int(tool_input.get("limit") or 5), 50))

    # Direct dataset lookup.
    if dataset_key and dataset_key in data:
        entry = data[dataset_key]
        rows = entry.get("rows", [])[:limit] if isinstance(entry, dict) else []
        return {
            "dataset": dataset_key,
            "title": entry.get("title", "") if isinstance(entry, dict) else "",
            "total_rows": len(entry.get("rows", [])) if isinstance(entry, dict) else 0,
            "rows": rows,
        }

    # Keyword search across dataset titles.
    matches = []
    for key, entry in data.items():
        if key.startswith("_"):
            continue
        if not isinstance(entry, dict):
            continue
        title = str(entry.get("title", "")).lower()
        if keyword and keyword not in title and keyword not in key:
            continue
        rows = entry.get("rows", [])
        matches.append({
            "dataset": key,
            "title": entry.get("title", ""),
            "row_count": len(rows) if isinstance(rows, list) else 0,
        })
    return {
        "query": dataset_key or keyword or "*",
        "datasets_found": len(matches),
        "datasets": matches[:limit],
    }


def _phone_osint_lookup(*, tool_input: dict[str, Any]) -> dict[str, Any]:
    """PhoneNumber-OSINT tool for phone validation, carrier and region intelligence."""
    raw_number = str(tool_input.get("phone") or tool_input.get("number") or "").strip()
    if not raw_number:
        return {"error": "Missing 'phone' or 'number' argument", "valid": False}

    default_region = str(tool_input.get("region") or "RU").strip().upper()

    try:
        import phonenumbers
        from phonenumbers import carrier, geocoder, timezone

        parsed = phonenumbers.parse(raw_number, default_region)
        is_valid = phonenumbers.is_valid_number(parsed)
        is_possible = phonenumbers.is_possible_number(parsed)
        num_type = phonenumbers.number_type(parsed)

        type_map = {
            0: "FIXED_LINE",
            1: "MOBILE",
            2: "FIXED_LINE_OR_MOBILE",
            3: "TOLL_FREE",
            4: "PREMIUM_RATE",
            5: "SHARED_COST",
            6: "VOIP",
            7: "PERSONAL_NUMBER",
            8: "PAGER",
            9: "UAN",
            10: "VOICEMAIL",
        }

        e164_format = phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)
        national_format = phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.NATIONAL)
        international_format = phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.INTERNATIONAL)

        region_name = geocoder.description_for_number(parsed, "ru") or geocoder.description_for_number(parsed, "en")
        carrier_name = carrier.name_for_number(parsed, "ru") or carrier.name_for_number(parsed, "en")
        time_zones = list(timezone.time_zones_for_number(parsed))

        # Check if local Nizhnevartovsk / KhMAO
        is_local_nv = (
            "Нижневартовск" in region_name
            or "Ханты-Мансийск" in region_name
            or "Тюменская" in region_name
            or (parsed.country_code == 7 and str(parsed.national_number).startswith("3466"))
        )

        return {
            "status": "success",
            "phone_raw": raw_number,
            "is_valid": is_valid,
            "is_possible": is_possible,
            "number_type": type_map.get(num_type, "UNKNOWN"),
            "e164": e164_format,
            "national": national_format,
            "international": international_format,
            "country_code": parsed.country_code,
            "region": region_name or "Не определен",
            "carrier": carrier_name or "Не определен",
            "timezones": time_zones,
            "is_local_nizhnevartovsk_khmao": is_local_nv,
        }
    except Exception as exc:
        return {
            "status": "error",
            "phone_raw": raw_number,
            "is_valid": False,
            "error": str(exc),
        }

