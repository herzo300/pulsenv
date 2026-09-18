"""Telegram publishing helpers."""

import logging

from .config import EMOJI, TAG, TARGET_CHANNEL
from .dedup import _check_duplicate_post

logger = logging.getLogger(__name__)


def _truncate_summary(summary: str, max_len: int = 150) -> str:
    """Обрезает сводку до max_len символов. В служебный канал — только краткая сводка, не весь пост."""
    if not summary or len(summary) <= max_len:
        return summary or ""
    return summary[: max_len - 3].rstrip() + "..."


def _get_source_icon(source_label, source_link):
    """Возвращает иконку соцсети для источника"""
    source_lower = source_label.lower()
    if (
        "telegram" in source_lower
        or "tg:" in source_lower
        or source_link.startswith("https://t.me")
    ):
        return "🔵"  # Telegram
    elif "vk" in source_lower or "vkontakte" in source_lower or "vk.com" in source_link:
        return "🔷"  # VK
    elif "instagram" in source_lower or "inst" in source_lower:
        return "📷"  # Instagram
    elif "facebook" in source_lower or "fb" in source_lower:
        return "📘"  # Facebook
    elif "twitter" in source_lower or "x.com" in source_lower:
        return "🐦"  # Twitter/X
    else:
        return "📢"  # Общая иконка


async def publish_to_telegram(
    client,
    category,
    report_id,
    summary,
    address,
    lat,
    lon,
    source_label,
    source_link,
    timestamp,
    geo_accuracy=None,
):
    """Публикует проблему в @monitornv с иконками соцсетей и ссылкой на маркер карты"""
    # Проверка дубликатов перед публикацией
    if await _check_duplicate_post(client, summary, address, lat, lon, category):
        logger.info(
            f"⏭️ Дубликат поста пропущен: {category} @ {address or f'{lat},{lon}'}"
        )
        return False

    summary = _truncate_summary(summary, 500)  # Increase limit for deep analysis
    emoji = EMOJI.get(category, "❔")
    tag = TAG.get(category, category.replace(" ", "_"))
    source_icon = _get_source_icon(source_label, source_link)

    lines = [f"{emoji} {category}"]
    if report_id:
        lines[0] += f" #{report_id}"
    lines.append("")
    lines.append(f"<b>Описание:</b>\n{summary}")

    # Публикуем адрес и карту ТОЛЬКО если уверены на 100% (geo_accuracy == "high")
    if geo_accuracy == "high" and address:
        lines.append("")
        lines.append(f"📍 <b>Адрес:</b> {address}")

        if lat and lon:
            lines.append(f"🗺️ {lat:.4f}, {lon:.4f}")
            sv_url = f"https://www.google.com/maps/@?api=1&map_action=pano&viewpoint={lat},{lon}&heading=0&pitch=0&fov=90"
            map_url = f"https://www.google.com/maps/search/?api=1&query={lat},{lon}"

            from core.config import PUBLIC_API_BASE_URL
            from services.admin_panel import get_webapp_version

            version = get_webapp_version()
            map_marker_url = f"{PUBLIC_API_BASE_URL}/map?v={version}&marker={lat},{lon}"

            map_links = f'👁 <a href="{sv_url}">Street View</a> | 📌 <a href="{map_url}">Google Maps</a>'
            map_links += f' | 🗺️ <a href="{map_marker_url}">На карте</a>'
            lines.append(map_links)

    lines.append("")
    # Источник с иконкой
    lines.append(f'{source_icon} <a href="{source_link}">{source_label}</a>')
    lines.append(f"🕐 {timestamp}")
    lines.append("")
    lines.append(f"#ГородскаяПроблема #{tag} #Нижневартовск")

    post_text = "\n".join(lines)
    try:
        await client.send_message(TARGET_CHANNEL, post_text, parse_mode="html")
        return True
    except Exception as e:
        logger.error(f"❌ Публикация TG: {e}")
        return False
