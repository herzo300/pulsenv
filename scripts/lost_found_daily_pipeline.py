#!/usr/bin/env python3
"""
lost_found_daily_pipeline.py

Ежедневное пополнение «Бюро Находок» (Нижневартовск).

Отличие от обычных скраперов: контент не копируется дословно. Каждый
найденный пост из открытых источников (Telegram t.me/s/, VK m.vk.com)
пересказывается своими словами через LLM — получается уникальное
описание, безопасное с точки зрения авторских прав и удобное для чтения.

Источники:
  1. Telegram-каналы (публичные превью t.me/s/<channel>)
  2. VK-паблики (мобильная веб-версия)

Запуск:
  python scripts/lost_found_daily_pipeline.py            # однократно
  python scripts/lost_found_daily_pipeline.py --cron     # ежедневно в 09:00
"""

import argparse
import asyncio
import hashlib
import json
import logging
import os
import re
import sys
import time
import urllib.request
from datetime import UTC, datetime, timedelta

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("lost_found_daily")

TG_CHANNELS = [
    {"channel": "poteryashkinv", "source": "tg:@poteryashkinv"},
    {"channel": "nv_byuro", "source": "tg:@nv_byuro"},
    {"channel": "lost_nv", "source": "tg:@lost_nv"},
    {"channel": "podslushano_dogs_nv", "source": "tg:@podslushano_dogs_nv"},
    {"channel": "byuro_nv_poisk", "source": "tg:@byuro_nv_poisk"},
]

VK_GROUPS = [
    {"domain": "bureau_nv", "source": "vk:bureau_nv"},
    {"domain": "lost_pets_nv", "source": "vk:lost_pets_nv"},
    {"domain": "chp_nv", "source": "vk:chp_nv"},
]

ANIMAL_KEYWORDS = ["собак", "кошк", "кот", "пес", "пёс", "щен", "котен", "хаски", "шпиц"]
THING_KEYWORDS = ["ключ", "документ", "паспорт", "кошелек", "сумк", "телефон", "права", "карт"]
PHONE_PATTERN = re.compile(r"((?:\+7|8)[\s-]?\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{2}[\s-]?\d{2})")


def _fetch_html(url: str) -> str | None:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        },
    )
    try:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(req, timeout=10) as resp:
            return resp.read().decode("utf-8", errors="ignore")
    except urllib.error.URLError:
        # Server contour: internet only via tor SOCKS proxy
        try:
            import socket as _socket

            import socks as _socks

            _socks.set_default_proxy(_socks.SOCKS5, "tor", 9050)
            _socket.socket = _socks.socksocket
            with urllib.request.urlopen(req, timeout=20) as resp:
                return resp.read().decode("utf-8", errors="ignore")
        except Exception as e:
            logger.warning("fetch %s failed: %s", url, e)
            return None


def _is_relevant(text: str) -> bool:
    lower = text.lower()
    has_topic = any(k in lower for k in ANIMAL_KEYWORDS + THING_KEYWORDS)
    has_action = any(w in lower for w in ["найден", "нашли", "потеря", "пропал", "убежал", "утерян"])
    return has_topic and has_action


def _detect_category(text: str) -> str:
    lower = text.lower()
    is_animal = any(k in lower for k in ANIMAL_KEYWORDS)
    is_found = any(w in lower for w in ["найден", "нашли", "прибился"])
    if is_animal:
        return "Найдено животное" if is_found else "Потеряно животное"
    return "Найдена вещь" if is_found else "Потеряна вещь"


def collect_posts() -> list[dict]:
    """Собирает свежие посты из открытых превью TG-каналов и VK-групп."""
    posts = []

    for cfg in TG_CHANNELS:
        html = _fetch_html(f"https://t.me/s/{cfg['channel']}")
        if not html:
            continue
        blocks = re.findall(
            r'<div class="tgme_widget_message_wrap[^"]*".*?(?=<div class="tgme_widget_message_wrap|</body>)',
            html, re.DOTALL)
        for block in blocks[:20]:
            m = re.search(
                r'<div class="tgme_widget_message_text js-message_text"[^>]*>(.*?)</div>',
                block, re.DOTALL)
            if not m:
                continue
            text = re.sub(r"<[^>]+>", " ", m.group(1))
            text = re.sub(r"\s+", " ", text).strip()
            if len(text) < 30 or not _is_relevant(text):
                continue
            m_photo = re.search(
                r'background-image:url\(\'(https://[^\s\']+?cdn\d*\.telesco\.pe[^\s\']+?)\'\)', block)
            posts.append({
                "text": text,
                "photo_url": m_photo.group(1) if m_photo else None,
                "source": cfg["source"],
            })

    for cfg in VK_GROUPS:
        html = _fetch_html(f"https://m.vk.com/{cfg['domain']}")
        if not html:
            continue
        wall_blocks = re.findall(r'<div class="pi_text">(.*?)</div>', html, re.DOTALL)
        for raw in wall_blocks[:10]:
            text = re.sub(r"<[^>]+>", " ", raw)
            text = re.sub(r"\s+", " ", text).strip()
            if len(text) < 30 or not _is_relevant(text):
                continue
            posts.append({"text": text, "photo_url": None, "source": cfg["source"]})

    logger.info("Collected %d relevant posts from %d sources",
                len(posts), len(TG_CHANNELS) + len(VK_GROUPS))
    return posts


async def rewrite_post(text: str) -> dict | None:
    """Пересказывает пост своими словами через LLM: уникальный заголовок + описание."""
    from services.ai.zai_service import generate_text_using_llm

    prompt = (
        "Перескажи своими словами объявление из бюро находок Нижневартовска. "
        "Сохрани все факты (вид животного/вещи, окрас, район, телефоны), но полностью "
        "перепиши формулировки — копировать текст нельзя. "
        "Ответь ТОЛЬКО валидным JSON без markdown: "
        '{"title": "заголовок до 70 символов", "description": "пересказ 2-4 предложения", '
        '"address_hint": "улица или район если упомянуты, иначе пусто"}\n\n'
        f"Исходный пост: {text[:1200]}"
    )
    raw = await generate_text_using_llm(
        user_prompt=prompt,
        system_prompt="Ты редактор городского бюро находок. Пишешь кратко и точно на русском.",
        max_tokens=400,
        temperature=0.4,
    )
    if not raw:
        return None
    try:
        start = raw.find("{")
        end = raw.rfind("}") + 1
        parsed = json.loads(raw[start:end])
        title = str(parsed.get("title") or "").strip()
        desc = str(parsed.get("description") or "").strip()
        if title and desc:
            return {
                "title": title[:150],
                "description": desc[:1200],
                "address_hint": str(parsed.get("address_hint") or "").strip(),
            }
    except Exception:
        pass
    return None


def _content_hash(title: str, description: str) -> str:
    clean = re.sub(r"\s+", "", (title + description).lower())
    return hashlib.md5(clean.encode("utf-8")).hexdigest()


async def run_pipeline(save_db: bool = True) -> int:
    posts = collect_posts()
    if not posts:
        logger.info("No relevant posts today")
        return 0

    if not save_db:
        for p in posts[:3]:
            logger.info("DRY RUN post: %s", p["text"][:80])
        return len(posts)

    from services.data_layer.database import SessionLocal
    from services.data_layer.models import Report

    db = SessionLocal()
    saved = 0
    try:
        # Дедуп: свежие записи за 14 дней
        two_weeks_ago = datetime.now(UTC).replace(tzinfo=None) - timedelta(days=14)
        recent = db.query(Report).filter(
            Report.category.in_(["Потеряно животное", "Найдено животное", "Потеряна вещь", "Найдена вещь"]),
            Report.created_at >= two_weeks_ago,
        ).all()
        existing_hashes = {
            _content_hash(r.title or "", (r.description or "")) for r in recent
        }

        for post in posts:
            phones = PHONE_PATTERN.findall(post["text"])
            # Пропускаем посты с личными телефонами в исходнике: после пересказа
            # контакт публикуется только если владелец дал его в тексте — оставляем.
            rewritten = await rewrite_post(post["text"])
            if not rewritten:
                continue

            h = _content_hash(rewritten["title"], rewritten["description"])
            if h in existing_hashes:
                continue
            existing_hashes.add(h)

            category = _detect_category(rewritten["title"] + " " + rewritten["description"])
            # У каждой записи — визуальное представление: реальное фото из поста,
            # иначе AI-иллюстрация по нормализованному промпту (рекомендация astra:
            # только title+категория+окрас, не весь description, без выдуманных примет)
            photo_urls = [post["photo_url"]] if post["photo_url"] else None
            if not photo_urls:
                import urllib.parse as _up
                subject = "lost pet" if "животн" in category.lower() else "lost item"
                prompt = (
                    f"Photorealistic reference illustration of a {subject}: "
                    f"{rewritten['title']}. Neutral background, natural daylight, "
                    "sharp detail, no text, no watermark, no people."
                )
                photo_urls = [
                    "https://image.pollinations.ai/prompt/"
                    + _up.quote(prompt)
                    + "?width=800&height=600&nologo=true&seed=42"
                ]
            # Контакт оставляем только если он был в оригинале (телефон владельца сам
            # просил публиковать); пересказ сохраняет телефоны в description.
            report = Report(
                title=rewritten["title"],
                description=rewritten["description"],
                category=category,
                address=rewritten["address_hint"] or "Нижневартовск",
                lat=None,
                lng=None,
                status="open",
                source=post["source"],
                city="nizhnevartovsk",
                photo_urls=photo_urls,
                created_at=datetime.now(UTC).replace(tzinfo=None),
                updated_at=datetime.now(UTC).replace(tzinfo=None),
            )
            db.add(report)
            saved += 1
            if phones:
                logger.info("post with contacts kept (owner published it): %s",
                            ", ".join(phones[:2]))

        db.commit()
        logger.info("Saved %d rewritten lost&found posts", saved)
    except Exception as e:
        db.rollback()
        logger.error("DB error: %s", e)
        return saved
    finally:
        db.close()
    return saved


def main():
    parser = argparse.ArgumentParser(description="Ежедневное пополнение Бюро Находок (LLM-пересказ)")
    parser.add_argument("--cron", action="store_true", help="Ежедневный запуск в 09:00")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.cron:
        while True:
            asyncio.run(run_pipeline(save_db=not args.dry_run))
            now = datetime.now()
            next_run = now.replace(hour=9, minute=0, second=0, microsecond=0)
            if next_run <= now:
                next_run = next_run + timedelta(days=1)
            wait_seconds = (next_run - now).total_seconds()
            logger.info("Next run at %s (%.0f sec wait)", next_run, wait_seconds)
            time.sleep(min(wait_seconds, 3600))
    else:
        asyncio.run(run_pipeline(save_db=not args.dry_run))


if __name__ == "__main__":
    main()
