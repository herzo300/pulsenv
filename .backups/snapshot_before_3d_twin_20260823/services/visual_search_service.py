# services/visual_search_service.py
"""
VIP Визуальный Поиск по камерам — поиск объекта (человек, животное, транспорт)
по текстовому описанию или фото через анализ снапшотов с городских камер.

Тарифы:
  VIP (999₽/мес)      — 10 поисков, 20 камер, апскейл, приоритет
  Standard (500₽/мес)  — 3 поиска, 15 камер, без апскейла
"""

import asyncio
import base64
import hashlib
import json
import logging
import os
import re
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from backend.database import SessionLocal
from backend.models import VipSubscription, VisualSearchLog
from core.http_client import get_http_client
from services.compliance_service import validate_visual_search

logger = logging.getLogger(__name__)

# Config — Z.AI (primary) с OpenRouter fallback
_zai_key = (os.getenv("ZAI_API_KEY", "")).strip()
_openrouter_key = os.getenv("OPENROUTER_API_KEY", "").strip()
_using_openrouter = not _zai_key and bool(_openrouter_key)
AI_API_KEY: str = _zai_key or _openrouter_key
AI_BASE: str = (
    os.getenv("ZAI_BASE_URL", "").strip()
    or ("https://openrouter.ai/api/v1" if _using_openrouter else "https://open.bigmodel.cn/api/paas/v4")
)
AI_VISION_MODEL: str = (
    os.getenv("ZAI_VISION_MODEL", "").strip()
    or (
        os.getenv("OPENROUTER_VISION_MODEL", "qwen/qwen-vl-plus")
        if _using_openrouter
        else "glm-4v-plus"
    )
)
VISUAL_SEARCH_MAX_CONCURRENCY = max(1, int(os.getenv("VISUAL_SEARCH_MAX_CONCURRENCY", "4")))

CAMERAS_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "public", "cameras_nv.json"
)

# Tier configs
TIER_CONFIG = {
    "vip": {
        "price": 999,
        "searches_limit": 10,
        "cameras_per_search": 20,
        "cooldown_sec": 300,     # 5 min
        "upscale": True,
        "priority": True,
    },
    "standard": {
        "price": 500,
        "searches_limit": 3,
        "cameras_per_search": 15,
        "cooldown_sec": 900,     # 15 min
        "upscale": False,
        "priority": False,
    },
}

SEARCH_PROMPT_TEMPLATE = (
    "Ты — система видеоаналитики города Нижневартовск. "
    "На снимке — кадр с городской камеры наблюдения.\n\n"
    "ЗАДАЧА: Определи, есть ли на снимке объект, соответствующий описанию:\n"
    '"{description}"\n\n'
    "ПРАВИЛА:\n"
    "1. Анализируй ТОЛЬКО видимые объекты на снимке\n"
    "2. Сравнивай по цвету одежды, размеру, породе, типу транспорта и т.д.\n"
    "3. НЕ распознавай лица (закон ФЗ-152)\n"
    "4. Оценивай уверенность от 0 до 1\n\n"
    'Верни ТОЛЬКО JSON: {{"match":true/false,"confidence":0.0-1.0,'
    '"description":"что именно видно на снимке, что совпадает или нет"}}'
)


def _parse_json_response(text: str) -> Optional[Dict[str, Any]]:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r"\{.*\}", text, re.DOTALL)
        if m:
            try:
                return json.loads(m.group())
            except json.JSONDecodeError:
                pass
    return None


def _load_cameras() -> List[Dict[str, Any]]:
    try:
        with open(CAMERAS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, list) else data.get("cameras", [])
    except Exception as e:
        logger.error("Camera load error: %s", e)
        return []


# ══════════════════════════════════════════════════════════════════════
# SUBSCRIPTION MANAGEMENT
# ══════════════════════════════════════════════════════════════════════

def get_subscription(telegram_id: int) -> Optional[VipSubscription]:
    db = SessionLocal()
    try:
        sub = db.query(VipSubscription).filter(
            VipSubscription.telegram_id == telegram_id
        ).first()
        if sub and sub.expires_at < datetime.utcnow():
            sub.is_active = False
            db.commit()
        return sub
    finally:
        db.close()


def activate_subscription(telegram_id: int, tier: str, payment_id: str = None) -> VipSubscription:
    cfg = TIER_CONFIG.get(tier, TIER_CONFIG["standard"])
    db = SessionLocal()
    try:
        sub = db.query(VipSubscription).filter(
            VipSubscription.telegram_id == telegram_id
        ).first()

        expires = datetime.utcnow() + timedelta(days=30)

        if sub:
            sub.tier = tier
            sub.searches_used = 0
            sub.searches_limit = cfg["searches_limit"]
            sub.expires_at = expires
            sub.is_active = True
            sub.payment_id = payment_id or sub.payment_id
        else:
            sub = VipSubscription(
                telegram_id=telegram_id,
                tier=tier,
                searches_used=0,
                searches_limit=cfg["searches_limit"],
                expires_at=expires,
                is_active=True,
                payment_id=payment_id,
            )
            db.add(sub)

        db.commit()
        db.refresh(sub)
        return sub
    finally:
        db.close()


def check_quota(telegram_id: int) -> Dict[str, Any]:
    """Check if user can perform a search. Returns status + details."""
    sub = get_subscription(telegram_id)
    if not sub or not sub.is_active:
        return {"allowed": False, "reason": "no_subscription", "message": "Нет активной подписки"}

    if sub.expires_at < datetime.utcnow():
        return {"allowed": False, "reason": "expired", "message": "Подписка истекла"}

    if sub.searches_used >= sub.searches_limit:
        return {
            "allowed": False,
            "reason": "quota_exceeded",
            "message": f"Лимит исчерпан ({sub.searches_used}/{sub.searches_limit})",
        }

    # Cooldown check
    cfg = TIER_CONFIG.get(sub.tier, TIER_CONFIG["standard"])
    db = SessionLocal()
    try:
        last_search = (
            db.query(VisualSearchLog)
            .filter(VisualSearchLog.telegram_id == telegram_id)
            .order_by(VisualSearchLog.created_at.desc())
            .first()
        )
        if last_search and last_search.created_at:
            elapsed = (datetime.utcnow() - last_search.created_at).total_seconds()
            if elapsed < cfg["cooldown_sec"]:
                remaining = int(cfg["cooldown_sec"] - elapsed)
                return {
                    "allowed": False,
                    "reason": "cooldown",
                    "message": f"Подождите {remaining} сек до следующего поиска",
                }
    finally:
        db.close()

    return {
        "allowed": True,
        "tier": sub.tier,
        "remaining": sub.searches_limit - sub.searches_used,
        "cameras": cfg["cameras_per_search"],
    }


def _increment_usage(telegram_id: int):
    db = SessionLocal()
    try:
        sub = db.query(VipSubscription).filter(
            VipSubscription.telegram_id == telegram_id
        ).first()
        if sub:
            sub.searches_used += 1
            db.commit()
    finally:
        db.close()


def _log_search(
    telegram_id: int, query_text: str, query_image_hash: str,
    cameras_scanned: int, matches_found: int, results: list,
    processing_time: float,
):
    db = SessionLocal()
    try:
        log = VisualSearchLog(
            telegram_id=telegram_id,
            query_text=query_text[:500] if query_text else None,
            query_image_hash=query_image_hash,
            cameras_scanned=cameras_scanned,
            matches_found=matches_found,
            results_json=json.dumps(results, ensure_ascii=False)[:5000],
            processing_time_sec=round(processing_time, 2),
        )
        db.add(log)
        db.commit()
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════════════
# VISUAL SEARCH ENGINE
# ══════════════════════════════════════════════════════════════════════

async def _fetch_snapshot(stream_url: str) -> Optional[bytes]:
    """Fetch snapshot from HLS camera stream."""
    if not stream_url:
        return None

    snapshot_urls = []
    if any(stream_url.lower().endswith(ext) for ext in (".jpg", ".jpeg", ".png")):
        snapshot_urls.append(stream_url)
    else:
        if "pride-net.ru" in stream_url:
            # Pride cameras: try to get a frame from HLS
            snapshot_urls.append(stream_url)
        elif "dantser.org" in stream_url:
            snapshot_urls.append(stream_url)
        snapshot_urls.append(stream_url.rstrip("/") + "/snapshot.jpg")

    for url in snapshot_urls:
        try:
            async with get_http_client(timeout=12.0) as client:
                r = await client.get(url, follow_redirects=True)
                if r.status_code == 200 and len(r.content) > 5000:
                    ct = r.headers.get("content-type", "")
                    if "image" in ct or len(r.content) > 10000:
                        return r.content
        except Exception:
            continue
    return None


async def _analyze_camera_for_target(
    image_bytes: bytes, description: str
) -> Optional[Dict[str, Any]]:
    """Send camera snapshot + search description to Z.AI Vision."""
    if not AI_API_KEY:
        return None

    image_b64 = base64.b64encode(image_bytes).decode("utf-8")
    prompt = SEARCH_PROMPT_TEMPLATE.format(description=description)

    payload = {
        "model": AI_VISION_MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"},
                    },
                ],
            }
        ],
        "temperature": 0.05,
    }

    headers = {
        "Authorization": f"Bearer {AI_API_KEY}",
        "Content-Type": "application/json",
    }

    proxy_url = None
    try:
        from core.http_client import get_proxy_url
        proxy_url = get_proxy_url()
    except Exception:
        pass

    try:
        async with get_http_client(timeout=45.0, proxy=proxy_url) as client:
            r = await client.post(
                f"{AI_BASE}/chat/completions", json=payload, headers=headers
            )
            if r.status_code == 200:
                data = r.json()
                content = (
                    data.get("choices", [{}])[0]
                    .get("message", {})
                    .get("content", "")
                )
                if content:
                    return _parse_json_response(content)
            else:
                logger.error("Visual search Z.AI HTTP %d", r.status_code)
    except Exception as e:
        logger.error("Visual search Z.AI error: %s", e)

    return None


async def run_visual_search(
    telegram_id: int,
    description: str,
    reference_image_bytes: bytes = None,
    max_cameras: int = None,
) -> Dict[str, Any]:
    """
    Main entry point: run visual search across city cameras.

    Returns: {
        "success": bool,
        "matches": [{camera_name, lat, lng, confidence, description}],
        "cameras_scanned": int,
        "processing_time_sec": float,
        "remaining_searches": int,
    }
    """
    start_time = time.time()

    # Check quota
    quota = check_quota(telegram_id)
    if not quota["allowed"]:
        return {
            "success": False,
            "error": quota["reason"],
            "message": quota["message"],
        }

    tier = quota["tier"]
    cfg = TIER_CONFIG.get(tier, TIER_CONFIG["standard"])
    cameras_count = max_cameras or cfg["cameras_per_search"]

    # Build search description
    search_desc = (description or "").strip()

    compliance = validate_visual_search(
        description=search_desc,
        has_reference_image=reference_image_bytes is not None,
    )
    if not compliance.allowed:
        return {
            "success": False,
            "error": compliance.error_code or "compliance_restricted",
            "message": compliance.message or "Search is unavailable",
        }

    # If reference image provided, describe it first
    if reference_image_bytes and AI_API_KEY:
        image_desc = await _describe_reference_image(reference_image_bytes)
        if image_desc:
            search_desc = f"{search_desc}. Визуальное описание: {image_desc}".strip(". ")

    search_desc = (search_desc or compliance.normalized_description or "").strip()
    if not search_desc:
        return {"success": False, "error": "empty_query", "message": "Укажите описание для поиска"}

    # Increment usage BEFORE search (to prevent abuse)
    _increment_usage(telegram_id)

    # Load cameras and scan a deterministic subset.
    cameras = _load_cameras()
    if not cameras:
        return {"success": False, "error": "no_cameras", "message": "Камеры недоступны"}

    selected_cameras = sorted(
        cameras,
        key=lambda cam: (
            str(cam.get("n") or cam.get("name") or ""),
            str(cam.get("s") or cam.get("stream_url") or ""),
        ),
    )[: min(cameras_count, len(cameras))]

    semaphore = asyncio.Semaphore(VISUAL_SEARCH_MAX_CONCURRENCY)
    tasks = [
        _scan_single_camera_limited(semaphore, cam, search_desc)
        for cam in selected_cameras
    ]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    matches = []
    scanned = len(selected_cameras)
    for cam, result in zip(selected_cameras, results):
        if isinstance(result, Exception):
            logger.debug("Visual search scan failed for %s: %s", cam.get("n"), result)
            continue
        if result and result.get("match") and result.get("confidence", 0) >= 0.5:
            matches.append({
                "camera_name": cam.get("n") or cam.get("name"),
                "lat": cam.get("lat"),
                "lng": cam.get("lng"),
                "stream_url": cam.get("s"),
                "confidence": result.get("confidence", 0),
                "description": result.get("description", ""),
            })

    # Sort by confidence
    matches.sort(key=lambda x: x.get("confidence", 0), reverse=True)

    processing_time = time.time() - start_time

    # Image hash for logging
    img_hash = hashlib.sha256(reference_image_bytes).hexdigest()[:16] if reference_image_bytes else None

    # Log
    _log_search(
        telegram_id=telegram_id,
        query_text=description,
        query_image_hash=img_hash,
        cameras_scanned=scanned,
        matches_found=len(matches),
        results=matches[:10],
        processing_time=processing_time,
    )

    sub = get_subscription(telegram_id)
    remaining = (sub.searches_limit - sub.searches_used) if sub else 0

    return {
        "success": True,
        "matches": matches[:10],
        "cameras_scanned": scanned,
        "matches_found": len(matches),
        "processing_time_sec": round(processing_time, 1),
        "remaining_searches": remaining,
        "tier": tier,
    }


async def _scan_single_camera(
    camera: Dict[str, Any], description: str
) -> Optional[Dict[str, Any]]:
    """Scan one camera: fetch snapshot → analyze for target."""
    stream_url = camera.get("s") or camera.get("stream_url") or ""
    snapshot = await _fetch_snapshot(stream_url)
    if not snapshot:
        return None
    return await _analyze_camera_for_target(snapshot, description)


async def _scan_single_camera_limited(
    semaphore: asyncio.Semaphore,
    camera: Dict[str, Any],
    description: str,
) -> Optional[Dict[str, Any]]:
    async with semaphore:
        return await _scan_single_camera(camera, description)


async def _describe_reference_image(image_bytes: bytes) -> Optional[str]:
    """Use Z.AI Vision to describe a reference image (what to search for)."""
    if not AI_API_KEY:
        return None

    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    payload = {
        "model": AI_VISION_MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": (
                            "Кратко опиши объект на фото для последующего поиска "
                            "по камерам наблюдения. Укажи: цвет одежды/шерсти, "
                            "размер, тип (человек/собака/машина), особые приметы. "
                            "НЕ описывай лицо. Ответь 1-2 предложениями."
                        ),
                    },
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"},
                    },
                ],
            }
        ],
        "temperature": 0.1,
    }

    headers = {
        "Authorization": f"Bearer {AI_API_KEY}",
        "Content-Type": "application/json",
    }

    try:
        proxy_url = None
        try:
            from core.http_client import get_proxy_url
            proxy_url = get_proxy_url()
        except Exception:
            pass

        async with get_http_client(timeout=30.0, proxy=proxy_url) as client:
            r = await client.post(
                f"{AI_BASE}/chat/completions", json=payload, headers=headers
            )
            if r.status_code == 200:
                data = r.json()
                return (
                    data.get("choices", [{}])[0]
                    .get("message", {})
                    .get("content", "")
                )
    except Exception as e:
        logger.error("Reference image describe error: %s", e)

    return None


# ══════════════════════════════════════════════════════════════════════
# STATUS / INFO
# ══════════════════════════════════════════════════════════════════════

def get_user_search_history(telegram_id: int, limit: int = 5) -> List[Dict]:
    db = SessionLocal()
    try:
        logs = (
            db.query(VisualSearchLog)
            .filter(VisualSearchLog.telegram_id == telegram_id)
            .order_by(VisualSearchLog.created_at.desc())
            .limit(limit)
            .all()
        )
        return [
            {
                "id": log.id,
                "query": log.query_text,
                "cameras_scanned": log.cameras_scanned,
                "matches_found": log.matches_found,
                "time_sec": log.processing_time_sec,
                "date": log.created_at.isoformat() if log.created_at else None,
            }
            for log in logs
        ]
    finally:
        db.close()
