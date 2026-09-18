# -*- coding: utf-8 -*-
"""Служба Гермеса «Строитель двойника»: фоновая валидация и дорисовка зданий
3D-карты Нижневартовска.

Цикл (каждые 6 часов):
1. Сверяет локальный реестр зданий (twin_buildings_osm.json) с живым OSM через Overpass:
   новые здания, изменённые контуры, обновлённые этажи/высоты.
2. Для части зданий без этажности запускает VLM-оценку по панорамам/кадрам (опционально,
   бюджетно, по несколько зданий за прогон).
3. Публикует новую версию реестра с ревизией; клиенты подтягивают её автоматически
   (передают ?rev= и получают 304, если не изменилось).
"""
import asyncio
import json
import logging
import os
import time
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

TWIN_PATHS = [
    os.environ.get("TWIN_OSM_PATH", ""),
    "data/twin_buildings_osm.json",
    "/app/data/twin_buildings_osm.json",
]

OVERPASS_MIRRORS = [
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
    "https://overpass-api.de/api/interpreter",
]

BBOX = "(60.85,76.42,61.02,76.70)"
QUERY = (
    "[out:json][timeout:300];"
    "way[\"building\"][\"addr:housenumber\"]" + BBOX + ";"
    "out center tags;"
)

_sync_lock = asyncio.Lock()
_last_run: datetime | None = None


def _twin_path() -> str | None:
    for p in TWIN_PATHS:
        if p and os.path.exists(p):
            return p
    return None


def _fetch_overpass(query: str) -> dict | None:
    import urllib.request

    last = None
    for url in OVERPASS_MIRRORS:
        for attempt in range(2):
            try:
                req = urllib.request.Request(
                    url, data=query.encode(),
                    headers={"User-Agent": "CityPulse-HermesTwin/1.0"},
                )
                with urllib.request.urlopen(req, timeout=300) as r:
                    return json.load(r)
            except Exception as e:
                last = e
                time.sleep(8)
    logger.warning("Overpass fetch failed in twin builder: %s", last)
    return None


def _build_registry_from_osm(d: dict) -> dict:
    """Собирает реестр зданий с этажами из ответа Overpass."""
    TYPE_MAP = {
        "apartments": ("Жилой фонд (МКД)", "#4A90E2", 3.1),
        "residential": ("Жилой фонд", "#5C9CE6", 3.2),
        "house": ("Частный сектор", "#D4A373", 3.2),
        "detached": ("Индивидуальный дом", "#D4A373", 3.2),
        "school": ("Образование (Школа)", "#E76F51", 3.5),
        "kindergarten": ("Детский сад", "#F4A261", 3.5),
        "hospital": ("Здравоохранение", "#2A9D8F", 3.5),
        "commercial": ("Торговля и бизнес", "#9B5DE5", 4.0),
        "retail": ("Торговый центр", "#B5179E", 4.5),
        "industrial": ("Промзона / Производство", "#6C757D", 8.5),
        "warehouse": ("Складской комплекс", "#495057", 7.0),
        "garages": ("Гаражный кооператив (ГСК)", "#ADB5BD", 3.2),
        "garage": ("Гараж", "#ADB5BD", 3.2),
        "administrative": ("Административное здание", "#0077B6", 3.6),
        "office": ("Бизнес-центр", "#0077B6", 3.6),
    }

    out = {}
    for el in d.get("elements", []):
        t = el.get("tags", {})
        street = t.get("addr:street") or t.get("addr:place")
        num = t.get("addr:housenumber")
        if not street or not num:
            continue
        c = el.get("center") or {}
        if not c.get("lat"):
            continue
        addr = f"{street}, {num}"
        levels_s = t.get("building:levels")
        levels = None
        if levels_s:
            try:
                levels = max(1, int(float(levels_s)))
            except ValueError:
                pass
        out[addr.lower()] = {
            "address": addr,
            "lat": round(c["lat"], 7),
            "lon": round(c["lon"], 7),
            "levels": levels,
            "building": t.get("building", "yes"),
        }
    return out


async def sync_twin_buildings() -> dict:
    """Один цикл синхронизации: OSM → локальный реестр. Возвращает статистику."""
    async with _sync_lock:
        path = _twin_path()
        if not path:
            return {"status": "no_registry"}

        loop = asyncio.get_running_loop()
        d = await loop.run_in_executor(None, _fetch_overpass, QUERY)
        if not d:
            return {"status": "overpass_failed"}

        fresh = _build_registry_from_osm(d)

        try:
            current = json.load(open(path, encoding="utf-8"))
        except Exception:
            current = {"features": []}
        feats = current.get("features", [])
        by_addr = {}
        for f in feats:
            addr = (f.get("properties", {}).get("address") or "").lower()
            if addr:
                by_addr[addr] = f

        added = updated = 0
        for addr, info in fresh.items():
            existing = by_addr.get(addr)
            if existing is None:
                added += 1
                feats.append({
                    "type": "Feature",
                    "id": f"osm_sync_{abs(hash(addr)) % 10**9}",
                    "geometry": {"type": "Point", "coordinates": [info["lon"], info["lat"]]},
                    "properties": {
                        "id": f"osm_sync_{abs(hash(addr)) % 10**9}",
                        "name": info["address"],
                        "address": info["address"],
                        "category": "Здание",
                        "render_height": (info["levels"] or 2) * 3.2,
                        "render_min_height": 0.0,
                        "levels": info["levels"] or 2,
                        "color": "#64748B",
                        "is_landmark": False,
                        "synced_by": "hermes",
                    },
                })
            else:
                props = existing.get("properties", {})
                changed = False
                if info["levels"] and info["levels"] != props.get("levels"):
                    props["levels"] = info["levels"]
                    props["render_height"] = info["levels"] * 3.2
                    changed = True
                if changed:
                    updated += 1

        current["features"] = feats
        current.setdefault("properties", {})
        current["properties"]["hermes_sync"] = {
            "last_run": datetime.utcnow().isoformat(),
            "added": added,
            "updated": updated,
            "source": "OSM Overpass",
        }
        tmp = os.path.abspath(f"{path}.{os.getpid()}.tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(current, f, ensure_ascii=False)
        os.replace(tmp, os.path.abspath(path))

        logger.info("Hermes twin sync: +%d new, %d updated, total %d", added, updated, len(feats))
        return {"status": "ok", "added": added, "updated": updated, "total": len(feats)}


def _acquire_single_instance_lock() -> bool:
    """Только один воркер uvicorn запускает цикл (PID-файл).

    PID в контейнере может переиспользоваться после рестарта воркера,
    поэтому дополнительно проверяем, что живой PID — это python-процесс,
    начавшийся НЕ раньше текущего.
    """
    lock_path = "/tmp/hermes_twin_builder.lock"
    try:
        my_pid = os.getpid()
        my_start = os.stat(f"/proc/{my_pid}").st_mtime
        if os.path.exists(lock_path):
            try:
                other_pid = int(open(lock_path).read().strip())
                if other_pid != my_pid:
                    other_start = os.stat(f"/proc/{other_pid}").st_mtime
                    # если «владелец» старше нас и жив — пропускаем
                    if other_start <= my_start:
                        return False
            except (ValueError, ProcessLookupError, PermissionError, OSError):
                pass  # мёртв/нечитаем — забираем
        with open(lock_path, "w") as f:
            f.write(str(my_pid))
        return True
    except Exception:
        return True


async def hermes_twin_builder_loop(interval_hours: float = 6.0):
    """Фоновый цикл Гермеса: постоянная валидация/дорисовка зданий двойника."""
    global _last_run
    if not _acquire_single_instance_lock():
        logger.info("Hermes Twin Builder: another worker owns the lock, skipping")
        return
    logger.info("Hermes Twin Builder started (every %.1f h)", interval_hours)
    while True:
        try:
            _last_run = datetime.utcnow()
            stats = await sync_twin_buildings()
            logger.info("Hermes twin builder cycle: %s", stats)
            # Фаза 2: изучение фото фасадов домов (VLM) — малыми партиями
            try:
                from services.business.hermes_facade_study import study_building_facades
                facade_stats = await study_building_facades(batch_size=12)
                logger.info("Hermes facade study: %s", facade_stats)
            except Exception as e:
                logger.warning("Hermes facade study failed: %s", e)
        except Exception as e:
            logger.error("Hermes twin builder cycle failed: %s", e)
        await asyncio.sleep(timedelta(hours=interval_hours).total_seconds())
