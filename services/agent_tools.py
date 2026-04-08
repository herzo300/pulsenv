from __future__ import annotations

from collections import Counter
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy.orm import Session

from backend.models import CameraAlert, Report


ALLOWED_TOOLS = {"camera_summary", "report_lookup"}


def run_tool(name: str, tool_input: dict[str, Any], db: Session) -> dict[str, Any]:
    if name not in ALLOWED_TOOLS:
        raise ValueError(f"Unsupported tool: {name}")
    if name == "camera_summary":
        return _camera_summary(db=db, tool_input=tool_input)
    if name == "report_lookup":
        return _report_lookup(db=db, tool_input=tool_input)
    raise ValueError(f"Unsupported tool: {name}")


def _camera_summary(*, db: Session, tool_input: dict[str, Any]) -> dict[str, Any]:
    hours = int(tool_input.get("hours") or 24)
    hours = max(1, min(hours, 168))
    since = datetime.utcnow() - timedelta(hours=hours)
    alerts = db.query(CameraAlert).filter(CameraAlert.created_at >= since).all()
    counts = Counter((alert.event_type or "unknown") for alert in alerts)
    return {
        "hours": hours,
        "total_alerts": len(alerts),
        "event_breakdown": dict(sorted(counts.items())),
    }


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
