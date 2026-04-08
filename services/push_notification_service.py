"""
Telegram delivery helpers used by monitoring, channel publication, and geo-pushes.
This module is intentionally independent from any interactive bot runtime.
"""

import asyncio
import logging
import math
import os
from datetime import datetime
from typing import Optional

import httpx

from backend.database import SessionLocal
from backend.models import GeoSubscription

logger = logging.getLogger(__name__)

_EARTH_R = 6_371_000


def _get_bot_token() -> str:
    return (os.getenv("TG_BOT_TOKEN") or os.getenv("TELEGRAM_BOT_TOKEN") or "").strip()


def _get_target_channel() -> str:
    return (os.getenv("TARGET_CHANNEL") or "@monitornv").strip()


async def _telegram_post(
    method: str,
    *,
    json_payload: dict | None = None,
    data_payload: dict | None = None,
    files: dict | None = None,
) -> bool:
    token = _get_bot_token()
    if not token:
        logger.warning("Telegram API call skipped: TG_BOT_TOKEN is not configured")
        return False

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"https://api.telegram.org/bot{token}/{method}",
                json=json_payload,
                data=data_payload,
                files=files,
            )
        if response.status_code != 200:
            logger.warning(
                "Telegram API %s failed: HTTP %s %s",
                method,
                response.status_code,
                response.text[:300],
            )
            return False
        payload = response.json()
        if not payload.get("ok"):
            logger.warning("Telegram API %s rejected request: %s", method, payload)
            return False
        return True
    except Exception as exc:
        logger.warning("Telegram API %s failed: %s", method, exc)
        return False


async def send_telegram_message(
    chat_id: int | str,
    text: str,
    *,
    parse_mode: str | None = None,
    disable_web_page_preview: bool = True,
) -> bool:
    payload = {
        "chat_id": str(chat_id),
        "text": text,
        "disable_web_page_preview": disable_web_page_preview,
    }
    if parse_mode:
        payload["parse_mode"] = parse_mode
    return await _telegram_post("sendMessage", json_payload=payload)


async def send_telegram_photo(
    chat_id: int | str,
    photo: bytes,
    *,
    filename: str = "alert.jpg",
    caption: str | None = None,
    parse_mode: str | None = None,
) -> bool:
    data_payload = {"chat_id": str(chat_id)}
    if caption:
        data_payload["caption"] = caption
    if parse_mode:
        data_payload["parse_mode"] = parse_mode
    files = {"photo": (filename, photo, "image/jpeg")}
    return await _telegram_post("sendPhoto", data_payload=data_payload, files=files)


async def send_push_notification(telegram_id: int, text: str) -> bool:
    return await send_telegram_message(telegram_id, text, parse_mode=None)


def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    rlat1, rlng1 = math.radians(lat1), math.radians(lng1)
    rlat2, rlng2 = math.radians(lat2), math.radians(lng2)
    dlat = rlat2 - rlat1
    dlng = rlng2 - rlng1
    a = math.sin(dlat / 2) ** 2 + math.cos(rlat1) * math.cos(rlat2) * math.sin(dlng / 2) ** 2
    return 2 * _EARTH_R * math.asin(math.sqrt(a))


def find_subscribers_in_radius(
    lat: float,
    lng: float,
    category: str = None,
    is_emergency: bool = False,
) -> list[GeoSubscription]:
    db = SessionLocal()
    try:
        lat_margin = 0.01
        lng_margin = 0.015
        subs = (
            db.query(GeoSubscription)
            .filter(
                GeoSubscription.is_active == True,
                GeoSubscription.lat.between(lat - lat_margin, lat + lat_margin),
                GeoSubscription.lng.between(lng - lng_margin, lng + lng_margin),
            )
            .all()
        )

        result: list[GeoSubscription] = []
        for sub in subs:
            dist = _haversine_m(lat, lng, sub.lat, sub.lng)
            if dist > sub.radius_m:
                continue
            if category and sub.categories and not is_emergency:
                allowed = [c.strip() for c in sub.categories.split(",")]
                if category not in allowed:
                    continue
            result.append(sub)
        return result
    finally:
        db.close()


async def notify_subscribers(
    bot=None,
    lat: float = None,
    lng: float = None,
    category: str = "",
    summary: str = "",
    address: str = None,
    report_id: int = None,
    is_emergency: bool = False,
    photo: bytes = None,
):
    if not lat or not lng:
        return 0

    subscribers = find_subscribers_in_radius(lat, lng, category, is_emergency=is_emergency)
    if not subscribers:
        return 0

    emoji_map = {
        "ЖКХ": "🏘️",
        "Дороги": "🛣️",
        "Благоустройство": "🌳",
        "Транспорт": "🚌",
        "Экология": "♻️",
        "Безопасность": "🚨",
        "Снег/Наледь": "❄️",
        "Освещение": "💡",
        "ЧП": "🚨",
        "Парковки": "🅿️",
    }
    emoji = emoji_map.get(category, "📣")

    if is_emergency:
        text = (
            "🚨 ЭКСТРЕННОЕ ПРЕДУПРЕЖДЕНИЕ (VIP-защита) 🚨\n\n"
            "AI-мониторинг зафиксировал угрозу в вашем радиусе.\n\n"
            f"📋 {category}"
        )
    else:
        text = f"{emoji} Новая городская проблема рядом с вами\n\n📋 {category}"

    if report_id:
        text += f" #{report_id}"
    if summary:
        text += f"\n📝 {summary[:300]}"
    if address:
        text += f"\n📍 {address}"
    text += "\n\n💡 Управление подписками доступно в приложении."

    sent = 0
    seen_tg_ids: set[int] = set()
    for sub in subscribers:
        if sub.telegram_id in seen_tg_ids:
            continue
        seen_tg_ids.add(sub.telegram_id)
        try:
            if photo:
                delivered = await send_telegram_photo(
                    sub.telegram_id,
                    photo,
                    caption=text,
                    parse_mode=None,
                )
            else:
                delivered = await send_telegram_message(sub.telegram_id, text, parse_mode=None)
            if delivered:
                sent += 1
        except Exception as exc:
            logger.debug("Push to %s failed: %s", sub.telegram_id, exc)
        if sent and sent % 25 == 0:
            await asyncio.sleep(1.1)

    logger.info(
        "Push sent to %d/%d subscribers for %s (emergency=%s)",
        sent,
        len(subscribers),
        category,
        is_emergency,
    )
    return sent


async def publish_report_to_channel(
    bot=None,
    category: str = "",
    summary: str = "",
    address: str = None,
    lat: float = None,
    lng: float = None,
    report_id: int = None,
    source_label: str = None,
    source_link: str = None,
    geo_accuracy: str = "medium",
):
    target_channel = _get_target_channel()

    emoji_map = {
        "ЖКХ": "🏘️",
        "Дороги": "🛣️",
        "Благоустройство": "🌳",
        "Транспорт": "🚌",
        "Экология": "♻️",
        "Безопасность": "🚨",
        "Снег/Наледь": "❄️",
        "Освещение": "💡",
        "ЧП": "🚨",
        "Парковки": "🅿️",
    }
    emoji = emoji_map.get(category, "📣")

    timestamp = datetime.now().strftime("%d.%m.%Y %H:%M")

    lines = [f"{emoji} {category}"]
    if report_id:
        lines[0] += f" #{report_id}"
    lines.append("")
    lines.append(f"<b>Описание:</b>\n{summary}")

    if geo_accuracy == "high" and address:
        lines.append("")
        lines.append(f"📍 <b>Адрес:</b> {address}")

        if lat and lng:
            lines.append(f"🗺️ {lat:.4f}, {lng:.4f}")
            sv_url = f"https://www.google.com/maps/@?api=1&map_action=pano&viewpoint={lat},{lng}&heading=0&pitch=0&fov=90"
            map_url = f"https://www.google.com/maps/search/?api=1&query={lat},{lng}"

            from core.config import PUBLIC_API_BASE_URL

            map_marker_url = f"{PUBLIC_API_BASE_URL}/map?marker={lat},{lng}"

            map_links = f'👁 <a href="{sv_url}">Street View</a> | 📌 <a href="{map_url}">Google Maps</a>'
            map_links += f' | 🗺️ <a href="{map_marker_url}">На карте</a>'
            lines.append(map_links)

    lines.append("")
    if source_label and source_link:
        lines.append(f'📣 <a href="{source_link}">{source_label}</a>')
    lines.append(f"🕐 {timestamp}")
    lines.append("")
    tag = category.replace(" ", "_").lower()
    lines.append(f"#ГородскаяПроблема #{tag} #Нижневартовск")

    post_text = "\n".join(lines)
    try:
        return await send_telegram_message(
            target_channel,
            post_text,
            parse_mode="HTML",
            disable_web_page_preview=False,
        )
    except Exception as exc:
        logger.error("Channel publication failed: %s", exc)
        return False


def add_subscription(
    telegram_id: int,
    lat: float,
    lng: float,
    radius_m: int = 500,
    label: str = None,
    categories: str = None,
) -> GeoSubscription:
    db = SessionLocal()
    try:
        sub = GeoSubscription(
            telegram_id=telegram_id,
            lat=lat,
            lng=lng,
            radius_m=radius_m,
            label=label,
            categories=categories,
        )
        db.add(sub)
        db.commit()
        db.refresh(sub)
        return sub
    finally:
        db.close()


def get_user_subscriptions(telegram_id: int) -> list[GeoSubscription]:
    db = SessionLocal()
    try:
        return (
            db.query(GeoSubscription)
            .filter(GeoSubscription.telegram_id == telegram_id)
            .order_by(GeoSubscription.created_at.desc())
            .all()
        )
    finally:
        db.close()


def delete_subscription(sub_id: int, telegram_id: int) -> bool:
    db = SessionLocal()
    try:
        sub = (
            db.query(GeoSubscription)
            .filter(GeoSubscription.id == sub_id, GeoSubscription.telegram_id == telegram_id)
            .first()
        )
        if sub:
            db.delete(sub)
            db.commit()
            return True
        return False
    finally:
        db.close()


def toggle_subscription(sub_id: int, telegram_id: int) -> Optional[bool]:
    db = SessionLocal()
    try:
        sub = (
            db.query(GeoSubscription)
            .filter(GeoSubscription.id == sub_id, GeoSubscription.telegram_id == telegram_id)
            .first()
        )
        if sub:
            sub.is_active = not sub.is_active
            db.commit()
            return sub.is_active
        return None
    finally:
        db.close()
