# services/Backend/services/house_sentinel_background.py — Реальный фоновый
# мониторинг домов для заданий ИИ-Гермеса. Периодически сканирует городские
# источники (ЕДДС-ленты, отключения, сигналы УК, публичные новости) на предмет
# упоминаний адреса дома и рассылает уведомления в комнаты WebSocket.
import asyncio
import logging
from datetime import datetime
from typing import Any, Dict, List

import httpx

logger = logging.getLogger(__name__)

# Задания: normalized_address -> task payload (живёт в house_community)
_TASKS: Dict[str, Dict[str, Any]] = {}

# Кэш последнего скана по каждому адресу
_LAST_SCAN: Dict[str, List[str]] = {}

SCAN_INTERVAL_SEC = 300  # каждые 5 минут
_city_cache: Dict[str, Any] = {"at": 0.0, "alerts": []}


def register_sentinel_task(normalized_address: str, task: Dict[str, Any]) -> None:
    """Регистрирует активное задание мониторинга дома."""
    _TASKS[normalized_address] = task
    if len(_TASKS) > 500:  # защита от разрастания
        for k in list(_TASKS.keys())[:100]:
            _TASKS.pop(k, None)


def drop_sentinel_task(normalized_address: str) -> None:
    _TASKS.pop(normalized_address, None)


def active_tasks() -> Dict[str, Dict[str, Any]]:
    return dict(_TASKS)


async def _fetch_city_alerts() -> List[Dict[str, Any]]:
    """Собирает свежие городские события: ЕДДС/отключения/сигналы из доступных API."""
    now = datetime.now().timestamp()
    if now - _city_cache["at"] < 240:  # кэш 4 минуты
        return _city_cache["alerts"]

    alerts: List[Dict[str, Any]] = []
    async with httpx.AsyncClient(timeout=8.0) as client:
        # 1. Сигналы жителей (негативные — аварии, ЖКХ-проблемы)
        try:
            r = await client.get("http://localhost:8000/api/reports?limit=30")
            if r.status_code == 200:
                data = r.json()
                items = data if isinstance(data, list) else data.get("reports", [])
                for it in items[:30]:
                    alerts.append({
                        "type": "resident_signal",
                        "title": str(it.get("title", "")),
                        "address": str(it.get("address", "")),
                        "category": str(it.get("category", "")),
                        "status": str(it.get("status", "")),
                    })
        except Exception as e:
            logger.debug("reports fetch: %s", e)

        # 2. Городские новости/тикер (паблики, администрация)
        try:
            r = await client.get(
                "http://localhost:8000/api/alerts/ticker?city=nizhnevartovsk")
            if r.status_code == 200:
                for it in (r.json().get("items") or [])[:20]:
                    alerts.append({
                        "type": "city_news",
                        "title": str(it.get("title") or it.get("text", "")),
                        "address": str(it.get("address", "")),
                        "category": str(it.get("category", "")),
                    })
        except Exception as e:
            logger.debug("ticker fetch: %s", e)

    _city_cache["at"] = now
    _city_cache["alerts"] = alerts
    return alerts


def _address_matches(alert: Dict[str, Any], normalized_address: str) -> bool:
    """Совпадение события с адресом дома: по подстроке улицы/номера."""
    text = f"{alert.get('address', '')} {alert.get('title', '')}".lower()
    if not text.strip():
        return False
    # Выделяем улицу и номер дома из normalized адреса («ул. мира, 10»)
    parts = normalized_address.replace("ул.", " ").replace("улица", " ").split(",")
    street = parts[0].strip() if parts else ""
    house_no = parts[1].strip() if len(parts) > 1 else ""
    street_hit = bool(street) and street in text
    number_hit = bool(house_no) and house_no in text
    return street_hit and number_hit


async def scan_all_and_notify() -> None:
    """Один цикл сканирования: для каждого активного дома ищет свежие события
    и рассылает в WebSocket-комнаты дома (чат Гермеса)."""
    if not _TASKS:
        return
    alerts = await _fetch_city_alerts()
    if not alerts:
        return

    # Поздний импорт — избегаем циклической зависимости
    from services.Backend.routers.house_community import manager as ws_manager

    for norm_addr, task in _TASKS.items():
        matched = [a for a in alerts if _address_matches(a, norm_addr)]
        # Дедупликация по заголовкам с прошлого скана
        seen = _LAST_SCAN.get(norm_addr, [])
        fresh = [a for a in matched if a["title"] not in seen][:5]
        _LAST_SCAN[norm_addr] = [a["title"] for a in matched][:50]

        if not fresh:
            continue

        task["last_monitored_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        task["active_alerts_count"] = len(matched)

        for a in fresh:
            icon = "🚨" if a["type"] == "resident_signal" else "📰"
            await ws_manager.broadcast_to_house(task.get("address", norm_addr), {
                "type": "hermes_house_alert",
                "address": task.get("address", norm_addr),
                "title": f"{icon} {a['title']}",
                "category": a.get("category", ""),
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            })
        logger.info("house sentinel %s: %d fresh alerts", norm_addr, len(fresh))


async def run_forever() -> None:
    """Бесконечный цикл фонового мониторинга домов."""
    logger.info("House Sentinel background loop started (%ds interval)", SCAN_INTERVAL_SEC)
    while True:
        try:
            await scan_all_and_notify()
        except Exception as e:
            logger.warning("house sentinel scan error: %s", e)
        await asyncio.sleep(SCAN_INTERVAL_SEC)
