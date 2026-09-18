"""Shared NVR helpers for Viseron and other video analytics backends."""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger(__name__)

CAMERA_ADDRESS_MAP: dict[str, str] = {
    "nv_60let_10": "60 лет Октября, 10",
    "nv_chapaeva_lenina": "перекрёсток Чапаева/Ленина",
    "nv_internatsionalnaya_13": "Интернациональная, 13",
    "nv_mira_32": "Мира, 32",
    "nv_geroyev_samotlora_20": "Героев Самотлора, 20",
    "nv_prospect_pobedy_5": "пр-т Победы, 5",
    "nv_hanty_mansiyskaya_19": "Ханты-Мансийская, 19",
    "nv_ploshchad_neftyannikov": "Площадь Нефтяников",
}

CAMERA_COORDS_MAP: dict[str, tuple[float, float]] = {
    "nv_60let_10": (60.928985, 76.557381),
    "nv_chapaeva_lenina": (60.939200, 76.561500),
    "nv_internatsionalnaya_13": (60.951000, 76.582000),
    "nv_mira_32": (60.944000, 76.601000),
    "nv_geroyev_samotlora_20": (60.931000, 76.642000),
    "nv_prospect_pobedy_5": (60.938000, 76.575000),
    "nv_hanty_mansiyskaya_19": (60.935000, 76.621000),
    "nv_ploshchad_neftyannikov": (60.940500, 76.545000),
}

CATEGORY_MAP = {
    "dump": "Бытовой мусор",
    "accident": "ДТП",
    "flood": "ЖКХ",
    "smoke": "Безопасность",
    "animals": "Животные",
    "crowd": "Безопасность",
    "traffic": "Транспорт",
    "motion": "Безопасность",
}

TITLE_PREFIX = {
    "frigate_ai": "Frigate AI",
    "viseron_ai": "Viseron AI",
}

EVENT_EMOJI = {
    "dump": "🗑️ Свалка",
    "accident": "🚗 ДТП",
    "flood": "💧 Затопление",
    "smoke": "🔥 Задымление",
    "animals": "🐕 Стая собак",
    "crowd": "👥 Скопление людей",
    "traffic": "🚦 Затор",
    "motion": "📹 Движение",
}


def normalize_camera_id(raw: str) -> str:
    """Map external camera identifiers to internal keys."""
    value = (raw or "").strip().lower()
    aliases = {
        "60let_10": "nv_60let_10",
        "camera1": "nv_60let_10",
        "nv_60let_10": "nv_60let_10",
    }
    if value in CAMERA_ADDRESS_MAP:
        return value
    return aliases.get(value, value)


async def save_nvr_alert(
    *,
    source: str,
    nvr_label: str,
    camera: str,
    alert: dict[str, Any],
    snapshot: bytes | None = None,
) -> int:
    from services.data_layer.database import SessionLocal
    from services.data_layer.models import CameraAlert, Report

    camera_key = normalize_camera_id(camera)
    coords = CAMERA_COORDS_MAP.get(camera_key, (0.0, 0.0))
    address = CAMERA_ADDRESS_MAP.get(camera_key, camera)
    event_type = alert.get("event_type", "unknown")
    confidence = float(alert.get("confidence", 0.0))
    prefix = TITLE_PREFIX.get(source, nvr_label)

    db = SessionLocal()
    try:
        db_alert = CameraAlert(
            camera_name=address,
            camera_lat=coords[0],
            camera_lng=coords[1],
            event_type=event_type,
            description=alert.get("description", ""),
            confidence=confidence,
        )
        db.add(db_alert)

        if coords[0] and coords[1] and address:
            db.add(
                Report(
                    title=f"{prefix}: {EVENT_EMOJI.get(event_type, event_type)}",
                    description=(
                        f"🤖 {nvr_label} ({int(confidence * 100)}%):\n"
                        f"{alert.get('description', '')}\n"
                        f"Камера: {address}"
                    ),
                    lat=coords[0],
                    lng=coords[1],
                    address=address,
                    category=CATEGORY_MAP.get(event_type, "Прочее"),
                    source=source,
                    status="pending",
                )
            )

        db.commit()
        db.refresh(db_alert)
        return db_alert.id
    finally:
        db.close()


async def send_nvr_notification(
    *,
    bot,
    nvr_label: str,
    camera: str,
    alert: dict[str, Any],
    alert_id: int,
    snapshot: bytes | None = None,
) -> None:
    camera_key = normalize_camera_id(camera)
    address = CAMERA_ADDRESS_MAP.get(camera_key, camera)
    event_type = alert.get("event_type", "?")
    event_label = EVENT_EMOJI.get(event_type, f"⚠️ {event_type}")
    conf_pct = int(float(alert.get("confidence", 0)) * 100)

    text = f"🔴 *{nvr_label} Alert #{alert_id}*\n\n{event_label}\n📹 {address}\n"
    if alert.get("description"):
        text += f"📝 {alert['description'][:200]}\n"
    text += f"🎯 Уверенность: {conf_pct}%\n"

    coords = CAMERA_COORDS_MAP.get(camera_key)
    if coords:
        text += f"📍 {coords[0]:.4f}, {coords[1]:.4f}\n"

    from core.config import TARGET_CHANNEL
    from services.push_notification_service import (
        send_telegram_message,
        send_telegram_photo,
    )

    try:
        if snapshot:
            await send_telegram_photo(
                TARGET_CHANNEL,
                snapshot,
                filename=f"{nvr_label.lower()}_incident.jpg",
                caption=text,
                parse_mode=None,
            )
        else:
            await send_telegram_message(TARGET_CHANNEL, text, parse_mode=None)
    except Exception as exc:
        logger.error("%s alert publish error: %s", nvr_label, exc)

    if coords:
        try:
            from services.push_notification_service import notify_subscribers

            await notify_subscribers(
                lat=coords[0],
                lng=coords[1],
                category="Безопасность",
                summary=f"[{nvr_label}] {event_label}: {alert.get('description', '')}",
                address=address,
                report_id=None,
                is_emergency=event_type in ("smoke", "animals", "accident"),
                photo=snapshot,
            )
        except Exception as exc:
            logger.debug("%s geo push error: %s", nvr_label, exc)
