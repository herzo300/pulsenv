from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

from sqlalchemy.orm import Session

from services.data_layer.models import Report

logger = logging.getLogger(__name__)

ALLOWED_TOOLS = {"report_lookup", "opendata_lookup"}

_OPENDATA_PATH = Path(__file__).resolve().parent.parent.parent / "opendata_full.json"
_opendata_cache: dict | None = None


def run_tool(name: str, tool_input: dict[str, Any], db: Session) -> dict[str, Any]:
    if name not in ALLOWED_TOOLS:
        raise ValueError(f"Unsupported tool: {name}")
    if name == "report_lookup":
        return _report_lookup(db=db, tool_input=tool_input)
    if name == "opendata_lookup":
        return _opendata_lookup(tool_input=tool_input)
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
