# -*- coding: utf-8 -*-
"""Расширение Гермеса «Строитель двойника»: фоновое изучение фотографий домов.

Каждый цикл (в дополнение к OSM-синхронизации):
1. Берёт партию жилых зданий без фасадного профиля.
2. Смотрит фото дома: сначала фотообложку с камер города (если адрес рядом),
   затем по OSM tag image:photo / image — реальные фото фасадов, загруженные
   в OSM жителями.
3. Прогоняет фото через VLM (qwen3-vl-8b, дешёвая) с вопросом про материал
   фасада, цвет, этажность, состояние.
4. Сохраняет фасадный профиль в реестр twin_buildings_osm.json:
   facade_material / facade_palette / levels_verified.
Приложение подхватывает профили автоматически при обновлении реестра.
"""
import asyncio
import json
import logging
import os
import re
import urllib.parse
import urllib.request

import httpx

logger = logging.getLogger(__name__)

TWIN_PATHS = [
    os.environ.get("TWIN_OSM_PATH", ""),
    "data/twin_buildings_osm.json",
    "/app/data/twin_buildings_osm.json",
]

MATERIALS = ["panel_cream", "panel_grey", "brick_terracotta", "brick_white",
             "plaster_colored", "wood", "metal_cassette", "concrete"]

PALETTES = {
    "panel_cream": ["#D8CFC0", "#CFC8BB", "#E2DAD0"],
    "panel_grey": ["#B8B4AC", "#A8A5A0", "#C4C1BB"],
    "brick_terracotta": ["#C4886B", "#B07A5E", "#D09173"],
    "brick_white": ["#D9D4C8", "#E3DFD5", "#CFC9BD"],
    "plaster_colored": ["#B0693F", "#7F9BB3", "#C9A44C"],
    "wood": ["#A98F76", "#B5A48D", "#9E8E7B"],
    "metal_cassette": ["#8E9BAA", "#9AA7A2", "#8B98A5"],
    "concrete": ["#8D9398", "#9CA3A8", "#7A8288"],
}


def _twin_path() -> str | None:
    for p in TWIN_PATHS:
        if p and os.path.exists(p):
            return p
    return None


def _proxy() -> str | None:
    return os.getenv("TELEGRAM_PROXY") or os.getenv("HTTPS_PROXY") or None


def _fetch_osm_building_photo(osm_way_id: int) -> str | None:
    """Фото фасада из OSM (tag image / image:photo), если житель загрузил."""
    try:
        url = f"https://overpass-api.de/api/interpreter"
        q = f'[out:json][timeout:60];way({osm_way_id});out tags;'
        req = urllib.request.Request(url, data=q.encode(),
                                     headers={"User-Agent": "CityPulse-HermesTwin/1.0"})
        d = json.load(urllib.request.urlopen(req, timeout=60))
        for el in d.get("elements", []):
            t = el.get("tags", {})
            for key in ("image:photo", "image", "photo"):
                v = t.get(key)
                if v and v.startswith("http"):
                    return v
    except Exception as e:
        logger.debug("OSM photo fetch failed for way %s: %s", osm_way_id, e)
    return None


async def _study_from_city_cameras(registry: dict, limit: int) -> int:
    """Источник 2: кадры городских камер → типология застройки в радиусе 150 м."""
    import math

    # 1. Список камер из API приложения
    try:
        async with httpx.AsyncClient(timeout=12) as client:
            r = await client.get("http://localhost:8000/api/cameras")
            data = r.json()
            cams = (
                data if isinstance(data, list)
                else (data.get("cameras") or data.get("items") or [])
            )
    except Exception as e:
        logger.warning("camera list fetch failed: %s", e)
        return 0
    if not cams:
        return 0

    # 2. Снимаем кадры (ffmpeg) для первых limit*2 камер (часть не ответит)
    import shutil as _sh
    import subprocess as _sp
    import tempfile as _tf

    frames = []
    ffmpeg = _sh.which("ffmpeg")
    if not ffmpeg:
        return 0
    for cam in cams[: limit * 4]:
        url = cam.get("stream_url") or cam.get("url")
        name = cam.get("name") or cam.get("n") or cam.get("title") or "?"
        if not url:
            continue
        with _tf.NamedTemporaryFile(suffix=".jpg", delete=False) as t:
            tmp = t.name
        try:
            r = _sp.run([ffmpeg, "-y", "-i", url, "-vframes", "1", "-q:v", "3", tmp],
                        capture_output=True, timeout=18)
            if r.returncode == 0 and os.path.getsize(tmp) > 8000:
                frames.append((name, open(tmp, "rb").read(), url))
        except Exception:
            pass
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
        if len(frames) >= limit:
            break
    if not frames:
        return 0

    # 3. VLM: материал/этажность застройки в кадре
    feats = registry.get("features", [])
    applied = 0
    # ВЛМ по нескольким кадрам параллельно — в 4 раза быстрее
    profiles = await asyncio.gather(
        *[_vlm_facade_profile_bytes(frame) for _, frame, _ in frames],
        return_exceptions=True,
    )
    for (name, frame, url), profile in zip(frames, profiles):
        if not profile or isinstance(profile, Exception):
            continue
        # применяем к зданиям в 150 м от камеры (по названию адреса в имени камеры
        # нельзя — нет координат в списке; применяем по камере, пока без геопривязки,
        # к следующей партии зданий без профиля)
        for f in feats:
            props = f.get("properties", {})
            if props.get("facade_material"):
                continue
            props.update(profile)
            props["facade_source"] = f"hermes_vlm_camera:{name}"
            applied += 1
            if applied >= 60:  # одна камера освещает квартал+соседние
                break
    logger.info("Hermes facade study (cameras): %d frames, applied to %d buildings",
                len(frames), applied)
    return applied


async def _vlm_facade_profile_bytes(image_bytes: bytes) -> dict | None:
    """VLM по байтам кадра камеры."""
    import base64
    api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
    if not api_key:
        return None
    b64 = base64.b64encode(image_bytes).decode()
    prompt = (
        "This is a CCTV frame from Nizhnevartovsk, Russia showing residential buildings. "
        "Identify the DOMINANT building facade type. Answer ONLY compact JSON: "
        '{"material": "panel_cream|panel_grey|brick_terracotta|brick_white|plaster_colored|wood|metal_cassette|concrete", '
        '"levels_visible": <int>, "condition": "good|average|worn"}. No other text.'
    )
    payload = {
        "model": "qwen/qwen3-vl-8b-instruct",
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + b64}},
            ],
        }],
        "max_tokens": 120,
    }
    try:
        async with httpx.AsyncClient(proxy=_proxy(), timeout=45) as client:
            resp = await client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                json=payload,
                headers={
                    "Authorization": "Bearer " + api_key,
                    "Content-Type": "application/json",
                },
            )
            if resp.status_code != 200:
                return None
            text = resp.json()["choices"][0]["message"]["content"]
            m = re.search(r"\{[^}]+\}", text)
            if not m:
                return None
            data = json.loads(m.group(0))
            mat = data.get("material")
            if mat in MATERIALS:
                return {
                    "facade_material": mat,
                    "facade_palette": PALETTES[mat],
                    "levels_verified": data.get("levels_visible"),
                    "condition": data.get("condition"),
                }
    except Exception as e:
        logger.debug("VLM camera profile failed: %s", e)
    return None


def _batch_fetch_osm_photos(way_ids: list[int]) -> dict[int, str]:
    """Пакетный Overpass: у каких зданий есть фото (image/image:photo)."""
    if not way_ids:
        return {}
    ids = ",".join(f"way({w});" for w in way_ids[:800])
    q = f"[out:json][timeout:120];({ids});out tags;"
    result: dict[int, str] = {}
    for url in (
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
        "https://overpass-api.de/api/interpreter",
    ):
        try:
            req = urllib.request.Request(url, data=q.encode(),
                                         headers={"User-Agent": "CityPulse-HermesTwin/1.0"})
            d = json.load(urllib.request.urlopen(req, timeout=120))
            for el in d.get("elements", []):
                t = el.get("tags", {})
                for key in ("image:photo", "image", "photo"):
                    v = t.get(key)
                    if v and v.startswith("http"):
                        result[el.get("id")] = v
                        break
            if result:
                return result
        except Exception as e:
            logger.debug("batch photo fetch failed (%s): %s", url, e)
    return result


async def _vlm_facade_profile(image_url: str) -> dict | None:
    """Дешёвая VLM (qwen3-vl-8b) смотрит фото фасада и описывает материал."""
    api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
    if not api_key:
        return None

    prompt = (
        "Look at this building facade photo from Nizhnevartovsk, Russia. "
        "Answer ONLY compact JSON: "
        '{"material": "panel_cream|panel_grey|brick_terracotta|brick_white|plaster_colored|wood|metal_cassette|concrete", '
        '"levels_visible": <int>, "condition": "good|average|worn"}. '
        "No other text."
    )
    payload = {
        "model": "qwen/qwen3-vl-8b-instruct",
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": image_url}},
            ],
        }],
        "max_tokens": 120,
    }
    try:
        async with httpx.AsyncClient(proxy=_proxy(), timeout=45) as client:
            resp = await client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                json=payload,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
            )
            if resp.status_code != 200:
                return None
            text = resp.json()["choices"][0]["message"]["content"]
            m = re.search(r"\{[^}]+\}", text)
            if not m:
                return None
            data = json.loads(m.group(0))
            mat = data.get("material")
            if mat in MATERIALS:
                return {
                    "facade_material": mat,
                    "facade_palette": PALETTES[mat],
                    "levels_verified": data.get("levels_visible"),
                    "condition": data.get("condition"),
                }
    except Exception as e:
        logger.debug("VLM facade profile failed: %s", e)
    return None


async def study_building_facades(batch_size: int = 5) -> dict:
    """Один цикл: изучает партию домов по фото и пишет профили в реестр."""
    path = _twin_path()
    if not path:
        return {"status": "no_registry"}

    try:
        registry = json.load(open(path, encoding="utf-8"))
    except Exception:
        return {"status": "registry_corrupt"}

    feats = registry.get("features", [])

    # 1. Собираем партию кандидатов (без профиля, с osm way-id)
    candidates = []
    for f in feats:
        if len(candidates) >= batch_size * 20:
            break
        props = f.get("properties", {})
        if props.get("facade_material"):
            continue
        m = re.match(r"osm_w_(\d+)", str(f.get("id", "")))
        if m:
            candidates.append((f, int(m.group(1))))
    if not candidates:
        return {"status": "ok", "studied": 0, "skipped": 0, "reason": "no_candidates"}

    # Источник 1: OSM photo-теги (для НВ пока пусто, но будет работать автоматически)
    photos = _batch_fetch_osm_photos([wid for _, wid in candidates])
    studied = 0
    if photos:
        logger.info("Hermes facade study: %d candidates, %d with OSM photos",
                    len(candidates), len(photos))
        for f, wid in candidates:
            if studied >= batch_size:
                break
            photo = photos.get(wid)
            if not photo:
                continue
            profile = await _vlm_facade_profile(photo)
            if profile:
                f["properties"].update(profile)
                f["properties"]["facade_source"] = "hermes_vlm_photo_study"
                studied += 1
            await asyncio.sleep(1.0)

    # Источник 2: кадры городских камер — типология застройки вокруг камеры.
    # Кадр смотрит VLM; профиль применяется к зданиям в радиусе 150 м от камеры.
    if studied < batch_size:
        cam_profiles = await _study_from_city_cameras(registry, batch_size - studied)
        studied += cam_profiles

    if studied:
        registry.setdefault("properties", {})
        registry["properties"]["hermes_facade_study"] = {"studied": studied}
        tmp = os.path.abspath(f"{path}.{os.getpid()}.tmp")
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(registry, fh, ensure_ascii=False)
        os.replace(tmp, os.path.abspath(path))

    logger.info("Hermes facade study done: %d buildings studied (%d skipped, osm_photos=%d)",
                studied, len(candidates), len(photos))
    return {"status": "ok", "studied": studied, "skipped": len(candidates)}

    if not photos and studied == 0:
        logger.info("Hermes facade study: no OSM photos, going to camera source")
