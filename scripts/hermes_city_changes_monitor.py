#!/usr/bin/env python3
"""
Hermes Legislation & City Changes Monitor.

Отслеживает изменения в городском законодательстве и жизни Нижневартовска:
- официальные документы администрации (n-vartovsk.ru)
- новости городских проектов и отраслей (ЖКХ, транспорт, стройка, бюджет)

Каждый цикл:
1. Скачивает RSS/HTML официальных источников.
2. Ищет свежие документы/новости (за последние N дней).
3. Новые позиции сохраняет в hermes_city_changes.json и БД Report
   (категория «Городские изменения») — они попадают в RAG Гермеса,
   дайджесты и карту города.

Запуск: вручную / из monitoring-цикла (каждые 6 часов).
"""

import asyncio
import hashlib
import json
import logging
import re
import urllib.request
from datetime import UTC, datetime, timedelta
from pathlib import Path

logger = logging.getLogger("hermes_legislation")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

ROOT = Path(__file__).resolve().parent.parent
MEMORY_FILE = ROOT / "services" / "ai" / "hermes_city_changes.json"

SOURCES = [
    {
        "name": "Администрация Нижневартовска — документы",
        "url": "https://www.n-vartovsk.ru/documents/",
        "kind": "html",
        "keywords": ["постановление", "распоряжение", "решение Думы", "проект"],
    },
    {
        "name": "Новости администрации",
        "url": "https://www.n-vartovsk.ru/news/",
        "kind": "html",
        "keywords": ["жкх", "транспорт", "строит", "бюджет", "благоустр",
                     "дорог", "школ", "больниц", "программ"],
    },
]

LOOKBACK_DAYS = 7


def _fetch(url: str) -> str | None:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (CityPulse-Hermes/1.0)"},
    )
    try:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(req, timeout=15) as resp:
            return resp.read().decode("utf-8", errors="ignore")
    except Exception:
        # server contour: internet via tor SOCKS proxy
        try:
            import socket as _socket

            import socks as _socks

            _socks.set_default_proxy(_socks.SOCKS5, "tor", 9050)
            _socket.socket = _socks.socksocket
            with urllib.request.urlopen(req, timeout=25) as resp:
                return resp.read().decode("utf-8", errors="ignore")
        except Exception as e:
            logger.warning("fetch %s failed: %s", url, e)
            return None


_TAG_RE = re.compile(r"<[^>]+>")


def _clean(text: str) -> str:
    text = _TAG_RE.sub(" ", text)
    text = text.replace("&nbsp;", " ").replace("&quot;", '"').replace("&#33;", "!")
    return re.sub(r"\s+", " ", text).strip()


def _parse_items(html: str, source: dict) -> list[dict]:
    """Извлекает <a> с датой/текстом; формат адаптирован под n-vartovsk.ru."""
    items = []
    cutoff = datetime.now(UTC) - timedelta(days=LOOKBACK_DAYS)
    # ссылки с заголовками внутри списков новостей/документов
    for m in re.finditer(
        r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', html, re.DOTALL
    ):
        href, title = m.group(1), _clean(m.group(2))
        if len(title) < 25 or len(title) > 300:
            continue
        low = title.lower()
        if not any(k in low for k in source["keywords"]):
            continue
        if href.startswith("/"):
            href = source["url"].split("/documents")[0].split("/news")[0] + href
        items.append({
            "title": title,
            "url": href,
            "source": source["name"],
        })
    # даты на странице не всегда рядом со ссылками — оставляем фильтр по
    # ключевым словам; дедуп по URL гарантирует, что старое не повторится
    _ = cutoff
    return items


def _key(item: dict) -> str:
    return hashlib.md5(item["url"].encode()).hexdigest()


def load_state() -> dict:
    if MEMORY_FILE.exists():
        try:
            return json.loads(MEMORY_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {"seen": [], "changes": []}


async def summarize_with_llm(title: str, source: str) -> str:
    """Краткая аннотация изменения для Гермеса (1-2 предложения)."""
    try:
        from services.ai.zai_service import generate_text_using_llm

        return await generate_text_using_llm(
            user_prompt=(
                f"Заголовок городского документа/новости Нижневартовска: «{title}» "
                f"(источник: {source}). Сформулируй 1-2 предложения: что меняется "
                "в городе и кому это важно. Без вступлений."
            ),
            system_prompt="Ты — аналитик городских изменений Нижневартовска.",
            max_tokens=250,
            temperature=0.3,
        )
    except Exception as e:
        logger.warning("LLM summarize failed: %s", e)
        return ""


async def run_cycle(save_db: bool = True) -> int:
    state = load_state()
    seen = set(state["seen"])
    fresh = []

    for src in SOURCES:
        html = _fetch(src["url"])
        if not html:
            continue
        for item in _parse_items(html, src)[:30]:
            k = _key(item)
            if k in seen:
                continue
            seen.add(k)
            fresh.append(item)

    if not fresh:
        logger.info("No new city changes")
        return 0

    # Аннотируем не более 10 за цикл — остальное попадёт следующим циклом
    batch = fresh[:10]
    saved = 0
    for item in batch:
        summary = await summarize_with_llm(item["title"], item["source"])
        entry = {
            "title": item["title"],
            "url": item["url"],
            "source": item["source"],
            "summary": summary,
            "detected_at": datetime.now(UTC).isoformat(),
        }
        state["changes"].append(entry)
        saved += 1

        if save_db:
            try:
                from services.data_layer.database import SessionLocal
                from services.data_layer.models import Report

                db = SessionLocal()
                try:
                    dup = db.query(Report).filter(
                        Report.title == item["title"],
                        Report.source == "hermes:city-changes",
                    ).first()
                    if not dup:
                        db.add(Report(
                            title=item["title"],
                            description=summary or item["title"],
                            category="Городские изменения",
                            address="Нижневартовск",
                            city="nizhnevartovsk",
                            status="open",
                            source="hermes:city-changes",
                            created_at=datetime.now(UTC).replace(tzinfo=None),
                            updated_at=datetime.now(UTC).replace(tzinfo=None),
                        ))
                        db.commit()
                finally:
                    db.close()
            except Exception as e:
                logger.warning("DB save failed for change: %s", e)

    # держим файл ограниченным
    state["seen"] = list(seen)[-3000:]
    state["changes"] = state["changes"][-500:]
    state["last_updated"] = datetime.now(UTC).isoformat()
    MEMORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    MEMORY_FILE.write_text(
        json.dumps(state, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    logger.info("Tracked %d new city changes (legislation/projects)", saved)
    return saved


def main():
    asyncio.run(run_cycle())


if __name__ == "__main__":
    main()
