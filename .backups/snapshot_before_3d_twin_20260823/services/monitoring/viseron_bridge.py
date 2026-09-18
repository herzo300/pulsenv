"""
Viseron → City Pulse bridge.

Viseron (https://github.com/roflcoopter/viseron) — self-hosted NVR с object/motion
detection. С v3.3+ поддерживает Webhook component: при событии на камере шлёт HTTP POST
в наш API, мы создаём маркер на карте и push-уведомление.

Face recognition в Viseron намеренно не используем (ФЗ-152).
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import logging
import os
import time
from typing import Any

from services.monitoring.nvr_common import (
    CAMERA_ADDRESS_MAP,
    normalize_camera_id,
    save_nvr_alert,
    send_nvr_notification,
)

logger = logging.getLogger(__name__)

VISERON_ENABLED = os.getenv("VISERON_ENABLED", "true").lower() == "true"
VISERON_WEBHOOK_TOKEN = (os.getenv("VISERON_WEBHOOK_TOKEN") or "").strip()
EVENT_COOLDOWN_SEC = int(os.getenv("VISERON_EVENT_COOLDOWN_SEC", "900"))
VISERON_AUTO_ALERTS = os.getenv("VISERON_AUTO_ALERTS", "false").lower() == "true"

_cooldowns: dict[str, float] = {}
_stats = {"received": 0, "accepted": 0, "ignored": 0, "last_event_at": None}


def verify_webhook_token(provided: str | None) -> bool:
    expected = VISERON_WEBHOOK_TOKEN
    if not expected:
        return VISERON_ENABLED
    if not provided:
        return False
    return hmac.compare_digest(provided.strip(), expected)


def get_viseron_status() -> dict[str, Any]:
    return {
        "enabled": VISERON_ENABLED,
        "webhook_configured": bool(VISERON_WEBHOOK_TOKEN),
        "stats": _stats,
        "cameras": list(CAMERA_ADDRESS_MAP.keys()),
    }


def _decode_snapshot(payload: dict[str, Any]) -> bytes | None:
    raw = payload.get("snapshot_base64") or payload.get("snapshot") or payload.get("image")
    if not raw or not isinstance(raw, str):
        return None
    if raw.startswith("data:"):
        raw = raw.split(",", 1)[-1]
    try:
        return base64.b64decode(raw, validate=False)
    except Exception:
        return None


def _map_label_to_event(label: str, count: int = 1) -> dict[str, Any] | None:
    label = (label or "").lower()
    if label in ("person", "people") and count >= int(os.getenv("CROWD_THRESHOLD", "6")):
        return {
            "event_type": "crowd",
            "confidence": min(0.55 + count * 0.05, 0.95),
            "description": f"Скопление людей (~{count})",
        }
    if label in ("dog", "cat", "animal") and count >= int(os.getenv("DOG_PACK_THRESHOLD", "3")):
        return {
            "event_type": "animals",
            "confidence": min(0.5 + count * 0.08, 0.92),
            "description": f"Группа животных (~{count})",
        }
    if label in ("car", "truck", "bus", "vehicle") and count >= int(
        os.getenv("VEHICLE_CLUSTER_THRESHOLD", "8")
    ):
        return {
            "event_type": "traffic",
            "confidence": 0.7,
            "description": f"Плотный транспортный поток (~{count})",
        }
    if label in ("motion", "motion_detected"):
        return {
            "event_type": "motion",
            "confidence": 0.6,
            "description": "Зафиксировано движение",
        }
    return None


def parse_viseron_payload(payload: dict[str, Any]) -> tuple[str, dict[str, Any]] | None:
    """
    Accept Viseron webhook JSON or simplified manual test payload.

    Expected fields (flexible):
      - camera / camera_identifier / camera_id
      - label / object / event
      - count (optional)
      - description (optional)
      - confidence (optional)
      - event_type (optional, bypass mapping)
    """
    camera = (
        payload.get("camera")
        or payload.get("camera_identifier")
        or payload.get("camera_id")
        or payload.get("camera_name")
        or ""
    )
    if not camera:
        event_name = str(payload.get("event") or payload.get("trigger") or "")
        if "/" in event_name:
            camera = event_name.split("/", 1)[0]

    camera = normalize_camera_id(str(camera))
    if not camera:
        return None

    if payload.get("event_type"):
        alert = {
            "event_type": payload["event_type"],
            "confidence": float(payload.get("confidence", 0.75)),
            "description": payload.get("description") or payload.get("message") or "",
        }
        return camera, alert

    label = str(
        payload.get("label")
        or payload.get("object")
        or payload.get("object_type")
        or payload.get("event")
        or "motion"
    )
    count = int(payload.get("count") or payload.get("object_count") or 1)
    alert = _map_label_to_event(label, count)
    if not alert:
        return None
    if payload.get("description"):
        alert["description"] = str(payload["description"])
    if payload.get("confidence") is not None:
        alert["confidence"] = float(payload["confidence"])
    return camera, alert


async def handle_viseron_webhook(payload: dict[str, Any], *, bot=None) -> dict[str, Any]:
    """Process one Viseron webhook call."""
    _stats["received"] += 1
    _stats["last_event_at"] = time.time()

    if not VISERON_ENABLED:
        _stats["ignored"] += 1
        return {"ok": False, "reason": "viseron_disabled"}

    parsed = parse_viseron_payload(payload)
    if not parsed:
        _stats["ignored"] += 1
        return {"ok": False, "reason": "unmapped_event"}

    camera, alert = parsed
    cooldown_key = f"{camera}:{alert.get('event_type')}"
    now = time.time()
    if cooldown_key in _cooldowns and now - _cooldowns[cooldown_key] < EVENT_COOLDOWN_SEC:
        _stats["ignored"] += 1
        return {"ok": False, "reason": "cooldown"}

    confidence = float(alert.get("confidence", 0))
    if confidence < 0.5:
        _stats["ignored"] += 1
        return {"ok": False, "reason": "low_confidence"}

    _cooldowns[cooldown_key] = now
    snapshot = _decode_snapshot(payload)

    if not VISERON_AUTO_ALERTS:
        _stats["accepted"] += 1
        logger.info(
            "Viseron webhook received for camera %s, event: %s. (Auto alerts disabled, skipping DB logging & notifications)",
            camera,
            alert.get("event_type")
        )
        return {
            "ok": True,
            "camera": camera,
            "event_type": alert.get("event_type"),
            "msg": "auto_alerts_disabled"
        }

    alert_id = await save_nvr_alert(
        source="viseron_ai",
        nvr_label="Viseron",
        camera=camera,
        alert=alert,
        snapshot=snapshot,
    )
    await send_nvr_notification(
        bot=bot,
        nvr_label="Viseron",
        camera=camera,
        alert=alert,
        alert_id=alert_id,
        snapshot=snapshot,
    )

    _stats["accepted"] += 1
    logger.warning(
        "Viseron alert #%s: %s @ %s",
        alert_id,
        alert.get("event_type"),
        camera,
    )
    return {
        "ok": True,
        "alert_id": alert_id,
        "camera": camera,
        "event_type": alert.get("event_type"),
    }


def payload_fingerprint(payload: dict[str, Any]) -> str:
    raw = repr(sorted(payload.items())).encode("utf-8", errors="replace")
    return hashlib.sha256(raw).hexdigest()[:16]
