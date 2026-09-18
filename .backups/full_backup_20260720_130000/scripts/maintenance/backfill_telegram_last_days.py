"""Backfill Telegram channel messages into the app map.

Only messages with a concrete, geocoded address are saved. The script does not
publish anything back to Telegram; it only writes deduplicated reports to the
application database.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

from dotenv import load_dotenv
from telethon import TelegramClient
import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

load_dotenv(ROOT / ".env")

from services.geo_service import geoparse, get_coordinates, sanitize_address_candidate
from services.business.category_service import categorize_text
from services.monitoring.config import API_HASH, API_ID, CHANNELS_TO_MONITOR
from services.monitoring.dedup import save_to_db
from services.monitoring.filters import is_ad_or_spam, is_relevant_message
from services.monitoring.pipeline import _has_concrete_address
from services.zai_service import build_marker_summary


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("backfill_telegram_last_days")


def _proxy_url() -> str | None:
    for key in ("TELEGRAM_PROXY", "HTTPS_PROXY", "ALL_PROXY"):
        value = (os.getenv(key) or "").strip()
        if value:
            return value
    return None


def _requests_proxies() -> dict[str, str] | None:
    proxy = _proxy_url()
    if not proxy:
        return None
    return {"http": proxy, "https": proxy}


def _telethon_proxy() -> tuple | None:
    proxy = _proxy_url()
    if not proxy:
        return None
    from urllib.parse import urlparse

    import socks

    parsed = urlparse(proxy)
    scheme = (parsed.scheme or "socks5").lower()
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or (1080 if "socks" in scheme else 8080)
    mapping = {
        "socks5": socks.SOCKS5,
        "socks4": socks.SOCKS4,
        "http": socks.HTTP,
        "https": socks.HTTP,
    }
    sock_type = mapping.get(scheme, socks.SOCKS5)
    username = parsed.username
    password = parsed.password
    if username or password:
        return (sock_type, host, port, True, username, password)
    return (sock_type, host, port)


def _mtproxy_config() -> tuple[type, tuple] | None:
    raw = (os.getenv("TELEGRAM_MTPROXY") or "").strip()
    if not raw:
        return None
    from telethon import connection

    parts = raw.split(":", 2)
    if len(parts) < 3:
        raise ValueError("TELEGRAM_MTPROXY must be host:port:hexsecret")
    host = parts[0]
    port = int(parts[1])
    secret_str = parts[2]
    if secret_str.startswith("ee") and len(secret_str) > 32:
        pass
    try:
        secret = bytes.fromhex(secret_str)
    except ValueError:
        try:
            secret = bytes.fromhex(secret_str[2:])
        except ValueError:
            raise ValueError(f"Invalid hex secret in TELEGRAM_MTPROXY: {secret_str}")
    return (
        connection.ConnectionTcpMTProxyRandomizedIntermediate,
        (host, port, secret),
    )


def build_telegram_client(session_name: str) -> TelegramClient:
    mtproxy = _mtproxy_config()
    if mtproxy:
        conn_type, proxy = mtproxy
        return TelegramClient(
            session_name,
            API_ID,
            API_HASH,
            connection=conn_type,
            proxy=proxy,
        )
    return TelegramClient(
        session_name,
        API_ID,
        API_HASH,
        proxy=_telethon_proxy(),
    )


# Backward-compatible alias for tooling scripts.
_build_telegram_client = build_telegram_client


KNOWN_STREET_NAMES = (
    "Мира",
    "Ленина",
    "Спортивная",
    "Омская",
    "Чапаева",
    "Пионерская",
    "Интернациональная",
    "Нефтяников",
    "Дружбы Народов",
    "Северная",
    "Маршала Жукова",
    "Таежная",
    "Мусы Джалиля",
    "Ханты-Мансийская",
    "60 лет Октября",
    "Индустриальная",
    "Рабочая",
    "Кузоваткина",
    "Авиаторов",
)

STREET_MARKER_RE = re.compile(
    r"\b(?P<prefix>ул\.|улица|проспект|пр-т|бульвар|б-р|переулок|пер\.|"
    r"набережная|наб\.|микрорайон|мкр\.)\s+"
    r"(?P<street>[А-ЯЁа-яё0-9][А-ЯЁа-яё0-9 .'-]{1,48}?)"
    r"(?:,|\s+)(?:д\.?\s*)?(?P<house>\d{1,3}[А-ЯЁа-яёA-Za-z]?(?:/\d{1,3})?)\b",
    re.IGNORECASE,
)

KNOWN_STREET_RE = re.compile(
    r"\b(?P<street>" + "|".join(re.escape(item) for item in KNOWN_STREET_NAMES) + r")"
    r"(?:\s*,|\s+)(?:д\.?\s*)?(?P<house>\d{1,3}[А-ЯЁа-яёA-Za-z]?(?:/\d{1,3})?)\b",
    re.IGNORECASE,
)


@dataclass
class BackfillStats:
    channels: int = 0
    scanned: int = 0
    too_old: int = 0
    empty: int = 0
    spam: int = 0
    irrelevant: int = 0
    no_confident_address: int = 0
    saved_new: int = 0
    merged_existing: int = 0
    errors: int = 0


def _channel_label(entity: object, fallback: str) -> tuple[str, str]:
    username = getattr(entity, "username", None)
    title = getattr(entity, "title", None) or username or fallback
    handle = f"@{username}" if username else fallback
    return handle, str(title)


def _category_from_text(text: str) -> str:
    return categorize_text(text)


def _confident_address_from_text(text: str) -> str | None:
    cleaned = re.sub(r"\s+", " ", text.replace("\xa0", " ")).strip()
    for pattern in (STREET_MARKER_RE, KNOWN_STREET_RE):
        match = pattern.search(cleaned)
        if not match:
            continue
        street = re.sub(r"\s+", " ", match.group("street")).strip(" ,.-")
        house = match.group("house").strip()
        if len(street) < 3:
            continue
        prefix = match.groupdict().get("prefix") or "ул."
        normalized = f"{prefix} {street} {house}, Нижневартовск"
        return sanitize_address_candidate(normalized) or normalized
    return None


def _set_report_original_date(report_id: int | None, msg_date: datetime | None) -> None:
    if not report_id or msg_date is None:
        return
    from services.data_layer.database import SessionLocal
    from services.data_layer.models import Report

    db = SessionLocal()
    try:
        report = db.query(Report).filter(Report.id == report_id).first()
        if not report:
            return
        original_date = msg_date.astimezone(timezone.utc).replace(tzinfo=None)
        report.created_at = original_date
        report.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.debug("Original date update failed for report %s: %s", report_id, exc)
    finally:
        db.close()


async def _process_message(client: TelegramClient, message: object) -> str:
    text = (getattr(message, "text", None) or getattr(message, "message", None) or "").strip()
    chat = await message.get_chat()
    source, source_label = _channel_label(chat, str(getattr(message, "chat_id", "telegram")))
    msg_id = getattr(message, "id", None)
    return await _process_payload(
        text=text,
        source=source,
        source_label=source_label,
        msg_id=msg_id,
        msg_date=getattr(message, "date", None),
    )


async def _process_payload(
    *,
    text: str,
    source: str,
    source_label: str,
    msg_id: int | str | None,
    msg_date: datetime | None = None,
) -> str:
    if len(text) < 12:
        return "empty"
    if is_ad_or_spam(text):
        return "spam"

    explicit_address = _confident_address_from_text(text)
    if not explicit_address or not _has_concrete_address(explicit_address):
        return "no_confident_address"

    category = _category_from_text(text)
    if not is_relevant_message(text, category):
        return "irrelevant"

    address = explicit_address
    coords = await get_coordinates(address)
    if coords is None:
        geo = await geoparse(text, ai_address=address, location_hints=address)
        if geo.get("address"):
            address = sanitize_address_candidate(geo["address"]) or address
        lat = geo.get("lat")
        lng = geo.get("lng")
    else:
        lat, lng = coords

    if not address or not _has_concrete_address(address) or lat is None or lng is None:
        return "no_confident_address"

    summary = build_marker_summary(text, text, max_len=120)
    report_id, is_new = await save_to_db(
        summary,
        text,
        lat,
        lng,
        address,
        category,
        source=f"tg:{source}",
        msg_id=msg_id,
        channel=source_label,
    )
    if not report_id:
        return "errors"
    if is_new:
        _set_report_original_date(report_id, msg_date)
    return "saved_new" if is_new else "merged_existing"


async def _run_telethon(days: int, limit_per_channel: int) -> BackfillStats:
    if not API_ID or not API_HASH:
        raise RuntimeError("TG_API_ID/TG_API_HASH are not configured")

    stats = BackfillStats(channels=len(CHANNELS_TO_MONITOR))
    since = datetime.now(timezone.utc) - timedelta(days=days)
    client = build_telegram_client("monitoring_session")

    async with client:
        for channel in CHANNELS_TO_MONITOR:
            logger.info("Scanning %s since %s", channel, since.isoformat())
            try:
                async for message in client.iter_messages(channel, limit=limit_per_channel):
                    msg_date = getattr(message, "date", None)
                    if msg_date and msg_date < since:
                        stats.too_old += 1
                        break
                    stats.scanned += 1
                    try:
                        result = await _process_message(client, message)
                    except Exception as exc:
                        stats.errors += 1
                        logger.warning("Message failed in %s: %s", channel, exc)
                        continue
                    setattr(stats, result, getattr(stats, result) + 1)
            except Exception as exc:
                stats.errors += 1
                logger.warning("Channel failed %s: %s", channel, exc)

    return stats


def _web_channel_name(channel: str) -> str:
    return channel.strip().lstrip("@")


def _fetch_web_page(channel: str, before: int | None) -> str:
    name = _web_channel_name(channel)
    url = f"https://t.me/s/{name}"
    if before:
        url = f"{url}?before={before}"
    response = requests.get(
        url,
        timeout=20,
        headers={"User-Agent": "Mozilla/5.0 (compatible; soobshio-backfill/1.0)"},
        proxies=_requests_proxies(),
    )
    response.raise_for_status()
    return response.text


def _parse_web_posts(channel: str, html: str) -> list[dict[str, object]]:
    soup = BeautifulSoup(html, "html.parser")
    posts: list[dict[str, object]] = []
    for node in soup.select(".tgme_widget_message"):
        post_id = node.get("data-post") or ""
        match = re.search(r"/(\d+)$", post_id)
        msg_id = int(match.group(1)) if match else None
        time_node = node.select_one("time")
        text_node = node.select_one(".tgme_widget_message_text")
        if not msg_id or not time_node or not text_node:
            continue
        try:
            msg_date = datetime.fromisoformat(
                (time_node.get("datetime") or "").replace("Z", "+00:00")
            )
        except ValueError:
            continue
        posts.append(
            {
                "id": msg_id,
                "date": msg_date,
                "text": text_node.get_text("\n", strip=True),
                "channel": channel,
            }
        )
    return posts


async def _run_web(days: int, limit_per_channel: int) -> BackfillStats:
    stats = BackfillStats(channels=len(CHANNELS_TO_MONITOR))
    since = datetime.now(timezone.utc) - timedelta(days=days)
    max_pages = max(1, (limit_per_channel // 20) + 2)

    for channel in CHANNELS_TO_MONITOR:
        before: int | None = None
        seen: set[int] = set()
        scanned_for_channel = 0
        logger.info("Web scanning %s since %s", channel, since.isoformat())
        for _ in range(max_pages):
            try:
                posts = _parse_web_posts(channel, _fetch_web_page(channel, before))
            except Exception as exc:
                stats.errors += 1
                logger.warning("Web channel failed %s: %s", channel, exc)
                break
            if not posts:
                break

            oldest_id = min(int(post["id"]) for post in posts)
            oldest_date = min(post["date"] for post in posts if isinstance(post["date"], datetime))
            for post in sorted(posts, key=lambda item: int(item["id"])):
                msg_id = int(post["id"])
                if msg_id in seen:
                    continue
                seen.add(msg_id)
                if scanned_for_channel >= limit_per_channel:
                    break
                msg_date = post["date"]
                if isinstance(msg_date, datetime) and msg_date < since:
                    stats.too_old += 1
                    continue
                stats.scanned += 1
                scanned_for_channel += 1
                result = await _process_payload(
                    text=str(post["text"]),
                    source=f"@{_web_channel_name(channel)}",
                    source_label=f"@{_web_channel_name(channel)}",
                    msg_id=msg_id,
                    msg_date=msg_date if isinstance(msg_date, datetime) else None,
                )
                setattr(stats, result, getattr(stats, result) + 1)

            if scanned_for_channel >= limit_per_channel or oldest_date < since:
                break
            before = oldest_id

    return stats


async def run(days: int, limit_per_channel: int, source: str) -> BackfillStats:
    if source == "web":
        return await _run_web(days, limit_per_channel)
    if source == "telethon":
        return await _run_telethon(days, limit_per_channel)
    try:
        return await _run_telethon(days, limit_per_channel)
    except Exception as exc:
        logger.warning("Telethon backfill failed, falling back to web: %s", exc)
        return await _run_web(days, limit_per_channel)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--days", type=int, default=3)
    parser.add_argument("--limit-per-channel", type=int, default=400)
    parser.add_argument(
        "--source",
        choices=("auto", "telethon", "web"),
        default="auto",
        help="Use MTProto, Telegram web preview, or auto fallback.",
    )
    args = parser.parse_args()

    proxy = _proxy_url()
    mtproxy = (os.getenv("TELEGRAM_MTPROXY") or "").strip()
    if mtproxy:
        logger.info("Using Telegram MTProxy (no full VPN required)")
    elif proxy:
        logger.info("Using proxy for Telegram access: %s", proxy.split("@")[-1])
    else:
        logger.warning(
            "No TELEGRAM_MTPROXY / TELEGRAM_PROXY — Telegram may be unreachable. "
            "Run: python scripts/maintenance/check_telegram_access.py"
        )

    stats = asyncio.run(run(args.days, args.limit_per_channel, args.source))
    print(
        {
            "channels": stats.channels,
            "scanned": stats.scanned,
            "saved_new": stats.saved_new,
            "merged_existing": stats.merged_existing,
            "no_confident_address": stats.no_confident_address,
            "irrelevant": stats.irrelevant,
            "spam": stats.spam,
            "empty": stats.empty,
            "too_old_boundaries": stats.too_old,
            "errors": stats.errors,
        }
    )
    return 0 if stats.errors == 0 or stats.scanned > 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
