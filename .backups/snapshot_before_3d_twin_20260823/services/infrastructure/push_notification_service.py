"""
Telegram delivery helpers used by monitoring, channel publication, and geo-pushes.
This module is intentionally independent from any interactive bot runtime.
"""

import asyncio
import logging
import math
import os
from datetime import datetime

import httpx

from services.data_layer.database import SessionLocal
from services.data_layer.models import GeoSubscription

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

    proxy = (os.getenv("TELEGRAM_PROXY") or os.getenv("HTTPS_PROXY") or os.getenv("ALL_PROXY") or "").strip()
    if not proxy:
        import socket
        try:
            socket.gethostbyname("soobshio_tor")
            proxy = "socks5h://soobshio_tor:9050"
            logger.info("Automatically detected 'soobshio_tor' container. Using Tor proxy: %s", proxy)
        except Exception:
            pass

    client_args = {"timeout": 15.0}
    if proxy:
        client_args["proxy"] = proxy

    try:
        async with httpx.AsyncClient(**client_args) as client:
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
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(rlat1) * math.cos(rlat2) * math.sin(dlng / 2) ** 2
    )
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

    subscribers = find_subscribers_in_radius(
        lat, lng, category, is_emergency=is_emergency
    )
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
                delivered = await send_telegram_message(
                    sub.telegram_id, text, parse_mode=None
                )
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
            .filter(
                GeoSubscription.id == sub_id, GeoSubscription.telegram_id == telegram_id
            )
            .first()
        )
        if sub:
            db.delete(sub)
            db.commit()
            return True
        return False
    finally:
        db.close()


def toggle_subscription(sub_id: int, telegram_id: int) -> bool | None:
    db = SessionLocal()
    try:
        sub = (
            db.query(GeoSubscription)
            .filter(
                GeoSubscription.id == sub_id, GeoSubscription.telegram_id == telegram_id
            )
            .first()
        )
        if sub:
            sub.is_active = not sub.is_active
            db.commit()
            return sub.is_active
        return None
    finally:
        db.close()


async def notify_report_status_change(report_id: int, old_status: str, new_status: str) -> None:
    """
    Notify report creator and nearby subscribers about status change.
    """
    from services.data_layer.models import User, Report
    db = SessionLocal()
    try:
        report = db.query(Report).filter(Report.id == report_id).first()
        if not report:
            return
            
        status_ru = {
            "open": "Открыта",
            "in_progress": "В работе",
            "resolved": "Решена",
            "verified": "Подтверждена ИИ",
            "rejected": "Отклонена"
        }
        
        old_lbl = status_ru.get((old_status or "").lower(), old_status or "На рассмотрении")
        new_lbl = status_ru.get((new_status or "").lower(), new_status or "Выполнена")
        
        # 1. Notify the author of the report if they are a Telegram user
        if report.user_id:
            user = db.query(User).filter(User.id == report.user_id).first()
            if user and user.telegram_id:
                msg = (
                    f"🔔 <b>Обновление статуса вашего сигнала #{report.id}</b>\n\n"
                    f"📋 Категория: {report.category}\n"
                    f"📍 Адрес: {report.address or 'Нижневартовск'}\n"
                    f"📝 Проблема: {report.title}\n\n"
                    f"📉 Предыдущий статус: {old_lbl}\n"
                    f"📈 <b>Новый статус: {new_lbl}</b>\n\n"
                    f"Спасибо за ваш вклад в улучшение Нижневартовска! 💙"
                )
                await send_telegram_message(user.telegram_id, msg, parse_mode="HTML")

        # 2. Notify neighbors in the radius if the report is resolved or verified
        if new_status and new_status.lower() in ("resolved", "verified") and report.lat and report.lng:
            subscribers = find_subscribers_in_radius(report.lat, report.lng, report.category)
            if subscribers:
                msg_neighbor = (
                    f"🎉 <b>Проблема решена рядом с вами!</b>\n\n"
                    f"📋 Категория: {report.category}\n"
                    f"📍 Адрес: {report.address or 'Нижневартовск'}\n"
                    f"📝 Суть: {report.title}\n\n"
                    f"✅ <b>Новый статус: {new_lbl}</b>\n\n"
                    f"Коммунальные службы отчитались об устранении нарушения. Проверьте результат при случае!"
                )
                seen_tg_ids = set()
                sent = 0
                for sub in subscribers:
                    # Don't notify the author twice
                    if report.user_id:
                        user = db.query(User).filter(User.id == report.user_id).first()
                        if user and sub.telegram_id == user.telegram_id:
                            continue
                    if sub.telegram_id in seen_tg_ids:
                        continue
                    seen_tg_ids.add(sub.telegram_id)
                    try:
                        if await send_telegram_message(sub.telegram_id, msg_neighbor, parse_mode="HTML"):
                            sent += 1
                    except Exception as e:
                        logger.debug("Failed neighbor status notify to %s: %s", sub.telegram_id, e)
                    if sent and sent % 25 == 0:
                        await asyncio.sleep(1.1)
                logger.info("Notified %d neighbors about resolved report #%s", sent, report.id)

    except Exception as exc:
        logger.error("Failed to notify status change for report #%s: %s", report_id, exc)
    finally:
        db.close()


async def trigger_push_for_report(report_id: int, client=None, force_cross_post: bool = False) -> None:
    """
    Triggers push notification (to channel and nearby subscribers) for a report.
    Guarantees that:
    - Push is sent EXACTLY once per report.
    - Historical/past signals are NOT pushed (fresh check: created within last 2 hours).
    - Only pushes signals from publics (tg/vk) or submitted by users (mobile_app, web, etc.).
    """
    from services.data_layer.models import Report
    from datetime import datetime, timedelta

    db = SessionLocal()
    try:
        report = db.query(Report).filter(Report.id == report_id).first()
        if not report:
            logger.warning("trigger_push_for_report: Report #%d not found", report_id)
            return

        # 1. Enforce EXACTLY ONCE push check
        if report.push_sent:
            logger.info("Signal #%d: Push already sent. Skipping.", report_id)
            return

        # 2. Enforce FRESHNESS check (not in the past)
        # Check report created time vs now. Max age: 2 hours.
        created_at_utc = report.created_at
        if created_at_utc.tzinfo is not None:
            from datetime import UTC
            created_at_utc = created_at_utc.astimezone(UTC).replace(tzinfo=None)
        
        now_utc = datetime.utcnow()
        age = now_utc - created_at_utc
        if age > timedelta(hours=2) or age < timedelta(hours=-2):
            logger.info("Signal #%d: is too far in past or future (created at %s, age %s). Skipping push.", report_id, report.created_at, age)
            return

        # 3. Enforce ALLOWED SOURCES check (publics or submitted by users)
        # Allowed sources: tg, vk, mobile_app, web, user, runtime, telegram, vkontakte, etc.
        source_lower = (report.source or "").lower()
        is_public = (
            source_lower.startswith("tg:")
            or source_lower.startswith("vk:")
            or "telegram" in source_lower
            or "vkontakte" in source_lower
            or source_lower == "telegram_monitoring"
        )
        is_user = source_lower in ("mobile_app", "web", "user", "runtime", "mobile")

        if not (is_public or is_user):
            logger.info("Signal #%d: Source '%s' is not allowed for pushing. Skipping.", report_id, report.source)
            return

        # 4. Perform the push notifications!
        # First, publish to the telegram channel if geo_accuracy is high or category is Event
        
        # Determine geo_accuracy
        geo_accuracy = "medium"
        if force_cross_post and report.address:
            geo_accuracy = "high"
        elif report.lat and report.lng:
            try:
                from services.monitoring.pipeline import _has_concrete_address
                if _has_concrete_address(report.address) and len(report.address.split()) >= 3:
                    geo_accuracy = "high"
            except Exception:
                if report.address and len(report.address.split()) >= 3:
                    geo_accuracy = "high"
        elif report.address:
            try:
                from services.monitoring.pipeline import _has_concrete_address
                if _has_concrete_address(report.address):
                    geo_accuracy = "high"
            except Exception:
                geo_accuracy = "high"

        # Publish to telegram channel if high accuracy or Event or force_cross_post
        if geo_accuracy == "high" or report.category == "Мероприятие" or force_cross_post:
            if client:
                try:
                    from services.monitoring.publisher import publish_to_telegram
                    from services.zai_service import build_marker_summary
                    
                    summary = build_marker_summary(report.description, report.description or "", max_len=120)
                    
                    # Map source prefix to label/link
                    source_label = report.telegram_channel or "Источник"
                    source_link = f"https://t.me/{report.telegram_channel.lstrip('@')}/{report.telegram_message_id}" if report.telegram_channel and report.telegram_message_id else "https://t.me/monitornv"
                    if source_lower.startswith("vk:"):
                        source_label = "ВКонтакте"
                        source_link = f"https://vk.com/wall{report.telegram_message_id}" if report.telegram_message_id else "https://vk.com"
                    
                    timestamp_str = report.created_at.strftime("%d.%m.%Y %H:%M")
                    
                    await publish_to_telegram(
                        client,
                        report.category,
                        report.id,
                        summary,
                        report.address,
                        report.lat,
                        report.lng,
                        source_label,
                        source_link,
                        timestamp_str,
                        geo_accuracy=geo_accuracy,
                    )
                except Exception as e:
                    logger.error("Failed to publish to telegram channel via client: %s", e)
            else:
                try:
                    # Bot API publishing
                    # Map source prefix to label/link
                    source_label = report.telegram_channel or "Источник"
                    source_link = f"https://t.me/{report.telegram_channel.lstrip('@')}/{report.telegram_message_id}" if report.telegram_channel and report.telegram_message_id else "https://t.me/monitornv"
                    if source_lower.startswith("vk:"):
                        source_label = "ВКонтакте"
                        source_link = f"https://vk.com/wall{report.telegram_message_id}" if report.telegram_message_id else "https://vk.com"
                    elif source_lower in ("mobile_app", "web", "user", "runtime"):
                        source_label = "Мобильное приложение"
                        source_link = "https://t.me/monitornv"
                    
                    await publish_report_to_channel(
                        category=report.category,
                        summary=report.title,
                        address=report.address,
                        lat=report.lat,
                        lng=report.lng,
                        report_id=report.id,
                        source_label=source_label,
                        source_link=source_link,
                        geo_accuracy=geo_accuracy,
                    )
                except Exception as e:
                    logger.error("Failed to publish to telegram channel via bot API: %s", e)
        else:
            logger.info("Signal #%d: geo_accuracy=%s — skipping telegram channel publication", report.id, geo_accuracy)

        # Second, notify nearby subscribers
        if report.lat and report.lng:
            try:
                await notify_subscribers(
                    lat=report.lat,
                    lng=report.lng,
                    category=report.category,
                    summary=report.title,
                    address=report.address,
                    report_id=report.id,
                )
            except Exception as e:
                logger.error("Failed to notify subscribers: %s", e)

        # 5. Mark as push sent
        report.push_sent = True
        db.commit()
        logger.info("Signal #%d: Push notification successfully sent and marked.", report_id)

    except Exception as e:
        db.rollback()
        logger.error("Error in trigger_push_for_report #%d: %s", report_id, e)
    finally:
        db.close()

