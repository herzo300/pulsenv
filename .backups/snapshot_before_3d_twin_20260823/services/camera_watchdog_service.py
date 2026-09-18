# services/camera_watchdog_service.py
"""
Camera Watchdog — автоматический анализ снапшотов городских камер через Z.AI Vision.
Фоновая задача: периодически делает скриншоты с камер и ищет:
  - Мусорные свалки
  - ДТП / аварии
  - Затопления
  - Задымление
  - Бродячие животные
"""

import asyncio
import base64
import json
import logging
import os
import re
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv

load_dotenv()

from backend.database import SessionLocal
from core.http_client import get_http_client

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

WATCHDOG_INTERVAL: int = int(os.getenv("WATCHDOG_INTERVAL_SEC", "600"))  # 10 min default
WATCHDOG_ENABLED: bool = os.getenv("WATCHDOG_ENABLED", "false").lower() == "true"
WATCHDOG_MAX_CONCURRENCY: int = max(1, int(os.getenv("WATCHDOG_MAX_CONCURRENCY", "4")))

# Cameras JSON path
CAMERAS_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "public", "cameras_nv.json"
)

WATCHDOG_PROMPT: str = (
    "Ты — система видеонаблюдения города Нижневартовск. "
    "Проанализируй снимок с городской камеры. "
    "Определи, есть ли на снимке ОДНА из следующих проблем:\n"
    "1. dump — несанкционированная мусорная свалка, мусор в неположенном месте\n"
    "2. accident — ДТП, авария, столкновение транспорта\n"
    "3. flood — затопление, прорыв воды, лужа на дороге блокирующая проезд\n"
    "4. smoke — задымление, пожар, дым\n"
    "5. animals — бродячая стая собак (3+ животных), опасное поведение\n"
    "6. none — ничего подозрительного (нормальная городская сцена)\n\n"
    "ВАЖНО: Не фиксируй нормальный мусор в урнах, штатно припаркованные авто, "
    "обычных прохожих или единичных собак на поводке.\n\n"
    'Верни ТОЛЬКО JSON: {"event_type":"none|dump|accident|flood|smoke|animals",'
    '"confidence":0.0-1.0,"description":"краткое описание или null"}'
)


def _parse_json(text: str) -> Optional[Dict[str, Any]]:
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
    """Load cameras from JSON file."""
    try:
        with open(CAMERAS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, list):
            return data
        return data.get("cameras", [])
    except Exception as e:
        logger.error("Camera load error: %s", e)
        return []


async def _fetch_snapshot(stream_url: str) -> Optional[bytes]:
    """
    Fetch a snapshot from camera stream URL.
    Supports: direct JPEG URLs, RTSP snapshot endpoints, HLS thumbnails.
    """
    if not stream_url:
        return None

    # Try direct download (many cameras expose /snapshot.jpg or similar)
    snapshot_urls = []

    # If it's already a direct image URL
    if any(stream_url.lower().endswith(ext) for ext in (".jpg", ".jpeg", ".png")):
        snapshot_urls.append(stream_url)
    else:
        # Cams-online.ru pattern: extract snapshot from stream page
        if "cams-online.ru" in stream_url:
            # Try thumbnail API
            snapshot_urls.append(stream_url.rstrip("/") + "/snapshot")
            snapshot_urls.append(stream_url.replace("/stream/", "/snapshot/"))
        # Generic: try appending /snapshot
        snapshot_urls.append(stream_url.rstrip("/") + "/snapshot.jpg")

    for url in snapshot_urls:
        try:
            async with get_http_client(timeout=15.0) as client:
                r = await client.get(url, follow_redirects=True)
                if r.status_code == 200 and len(r.content) > 5000:
                    content_type = r.headers.get("content-type", "")
                    if "image" in content_type or len(r.content) > 10000:
                        return r.content
        except Exception:
            continue

    return None


async def analyze_snapshot(image_bytes: bytes) -> Optional[Dict[str, Any]]:
    """Send snapshot to Z.AI Vision for analysis."""
    if not AI_API_KEY:
        return None

    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    payload = {
        "model": AI_VISION_MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": WATCHDOG_PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{image_b64}"
                        },
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
    if _using_openrouter:
        headers["HTTP-Referer"] = "https://soobshio.app"
        headers["X-Title"] = "Soobshio Watchdog"

    proxy_url = None
    try:
        from core.http_client import get_proxy_url
        proxy_url = get_proxy_url()
    except Exception:
        pass

    try:
        async with get_http_client(timeout=60.0, proxy=proxy_url) as client:
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
                    return _parse_json(content)
            else:
                logger.error("Watchdog Z.AI HTTP %d: %s", r.status_code, r.text[:200])
    except Exception as e:
        logger.error("Watchdog Z.AI error: %s", e)

    return None


async def scan_camera(camera: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Scan a single camera: fetch snapshot → YOLO edge filter → [escalate] → Z.AI Vision → alert."""
    stream_url = camera.get("s") or camera.get("stream_url") or ""
    name = camera.get("n") or camera.get("name") or "Unknown"
    camera_id = camera.get("id") or name

    snapshot = await _fetch_snapshot(stream_url)
    if not snapshot:
        return None

    # ─── Уровень 1: Локальный YOLO edge-фильтр (бесплатно) ───
    try:
        from services.yolo_edge_filter import analyze_frame
        edge = analyze_frame(snapshot, camera_id=camera_id)

        if not edge.get("should_escalate", True):
            logger.debug(
                "⚡ YOLO skip: %s (%s)",
                name,
                edge.get("summary", "clean"),
            )
            return None

        logger.info(
            "🔍 YOLO → escalate: %s | reason=%s | %s",
            name,
            edge.get("reason", "?"),
            edge.get("summary", ""),
        )
    except Exception as e:
        # Если YOLO недоступен — fallback к старому поведению (всегда API)
        logger.debug("Edge filter unavailable (%s), using API directly: %s", name, e)

    # ─── Уровень 2a: Локальный SmolVLM (бесплатно, ~3-8 сек) ───
    result = None
    try:
        from services.smolvlm_service import analyze_image_local
        result = await analyze_image_local(snapshot)
        if result:
            logger.info("🧠 SmolVLM local analysis: %s → %s (%.0f%%)",
                        name, result.get("event_type"), result.get("confidence", 0) * 100)
    except Exception as e:
        logger.debug("SmolVLM unavailable: %s", e)

    # ─── Уровень 2b: Cloud AI fallback (только если SmolVLM не ответил и БЮДЖЕТ ≤ 1000 руб/мес) ───
    if not result:
        try:
            from services.camera_budget_controller import can_spend_paid_api, record_paid_spending
            if can_spend_paid_api(estimated_cost_usd=0.00012):
                result = await analyze_snapshot(snapshot)
                if result:
                    record_paid_spending(0.00012)
            else:
                logger.info("🔒 Budget Cap Enforced (1000 RUB/month max): skipped paid VLM for %s", name)
        except Exception as ex:
            logger.debug("Budget check error: %s", ex)
            result = await analyze_snapshot(snapshot)

    if not result:
        return None

    event_type = result.get("event_type", "none")
    confidence = result.get("confidence", 0.0)

    if event_type == "none" or confidence < 0.6:
        return None

    return {
        "camera_name": name,
        "camera_lat": camera.get("lat"),
        "camera_lng": camera.get("lng"),
        "event_type": event_type,
        "description": result.get("description"),
        "confidence": confidence,
        "snapshot": snapshot,
    }



async def _save_alert(alert_data: Dict[str, Any]) -> int:
    """Save alert to database."""
    from backend.models import CameraAlert, Report

    db = SessionLocal()
    try:
        # 1. Запись в техническую таблицу CameraAlert
        alert = CameraAlert(
            camera_name=alert_data["camera_name"],
            camera_lat=alert_data.get("camera_lat"),
            camera_lng=alert_data.get("camera_lng"),
            event_type=alert_data["event_type"],
            description=alert_data.get("description"),
            confidence=alert_data.get("confidence", 0.0),
        )
        db.add(alert)
        
        # 2. Создание маркера (Report) для отображения в мобильном приложении
        CAT_MAP = {
            "dump": "Бытовой мусор", 
            "accident": "ДТП", 
            "flood": "ЖКХ", 
            "smoke": "Безопасность",     
            "animals": "Животные",
        }
        
        TITLE_MAP = {
            "dump": "Автоматическая фиксация: Свалка мусора",
            "accident": "Автоматическая фиксация: ДТП",
            "flood": "Автоматическая фиксация: Затопление",
            "smoke": "Автоматическая фиксация: Задымление",
            "animals": "Автоматическая фиксация: Стая собак",
        }
        
        rep_ctg = CAT_MAP.get(alert_data["event_type"], "other")
        rep_title = TITLE_MAP.get(alert_data["event_type"], "Событие с камеры")
        
        if alert_data.get("camera_lat") and alert_data.get("camera_lng"):
            report = Report(
                title=rep_title,
                description=f"🤖 ИИ-наблюдатель ({int(alert_data.get('confidence',0)*100)}%):\n" + alert_data.get("description", ""),
                lat=alert_data.get("camera_lat"),
                lng=alert_data.get("camera_lng"),
                address=alert_data["camera_name"],
                category=rep_ctg,
                source="camera_ai",
                status="pending"
            )
            db.add(report)

        db.commit()
        db.refresh(alert)

        # 3. Автоматическое сохранение кадра в обучающий датасет для локального нейро-тренера
        if alert_data.get("snapshot"):
            try:
                from services.camera_dataset_collector import save_sample
                save_sample(
                    camera_name=alert_data["camera_name"],
                    event_type=alert_data["event_type"],
                    confidence=alert_data.get("confidence", 0.0),
                    description=alert_data.get("description"),
                    image_bytes=alert_data["snapshot"],
                    lat=alert_data.get("camera_lat"),
                    lng=alert_data.get("camera_lng"),
                )
            except Exception as ex:
                logger.debug("Dataset save error: %s", ex)

        return alert.id
    finally:
        db.close()


async def _send_alert_notification(bot, alert_data: Dict[str, Any], alert_id: int):
    """Send alert notification to admin channel and push subscribers."""
    EVENT_EMOJI = {
        "dump": "🗑️ Свалка",
        "accident": "🚗 ДТП",
        "flood": "💧 Затопление",
        "smoke": "🔥 Задымление",
        "animals": "🐕 Бродячие животные",
    }

    event_label = EVENT_EMOJI.get(alert_data["event_type"], f"⚠️ {alert_data['event_type']}")
    conf_pct = int(alert_data.get("confidence", 0) * 100)

    text = (
        f"🔴 *Camera Watchdog Alert #{alert_id}*\n\n"
        f"{event_label}\n"
        f"📹 {alert_data['camera_name']}\n"
    )
    if alert_data.get("description"):
        text += f"📝 {alert_data['description'][:200]}\n"
    text += f"🎯 Уверенность: {conf_pct}%\n"

    if alert_data.get("camera_lat") and alert_data.get("camera_lng"):
        lat, lng = alert_data["camera_lat"], alert_data["camera_lng"]
        text += f"📍 {lat:.4f}, {lng:.4f}\n"

    # Send to admin channel
    from core.config import TARGET_CHANNEL
    from services.push_notification_service import send_telegram_message, send_telegram_photo
    try:
        if alert_data.get("snapshot"):
            await send_telegram_photo(
                TARGET_CHANNEL,
                alert_data["snapshot"],
                filename="incident.jpg",
                caption=text, 
                parse_mode=None,
            )
        else:
            await send_telegram_message(TARGET_CHANNEL, text, parse_mode=None)
    except Exception as e:
        logger.error("Watchdog alert publish error: %s", e)

    # Also notify geo-subscribers
    if alert_data.get("camera_lat") and alert_data.get("camera_lng"):
        try:
            from services.push_notification_service import notify_subscribers
            
            event_type = alert_data.get("event_type")
            is_vip_emergency = event_type in ("smoke", "animals")
            
            await notify_subscribers(
                lat=alert_data["camera_lat"],
                lng=alert_data["camera_lng"],
                category="Безопасность",
                summary=f"[Camera Watchdog] {event_label}: {alert_data.get('description', '')}",
                address=alert_data["camera_name"],
                report_id=None,
                is_emergency=is_vip_emergency,
                photo=alert_data.get("snapshot"),
            )
        except Exception as e:
            logger.debug("Watchdog push error: %s", e)


_watchdog_cycle_count: int = 0


def is_night_mode() -> bool:
    """Check if current local time in Nizhnevartovsk (UTC+5) is night (23:00 to 06:00)."""
    from datetime import datetime, timezone, timedelta
    local_now = datetime.now(timezone.utc) + timedelta(hours=5)
    return local_now.hour >= 23 or local_now.hour < 6


async def run_watchdog_cycle(bot=None, max_cameras: int = 10):
    """
    Single watchdog scan cycle with Night Mode adaptive filtering:
      • Day (06:00 - 23:00): 10 min scan interval for all cameras.
      • Night (23:00 - 06:00): 10 min for main intersections, 45 min for residential areas (-65% queries).
    """
    global _watchdog_cycle_count
    _watchdog_cycle_count += 1
    night_active = is_night_mode()

    cameras = _load_cameras()
    if not cameras:
        logger.warning("Watchdog: no cameras loaded")
        return []

    # Night mode adaptive filtering: skip 3 of 4 cycles for residential cameras at night
    filtered_cams = []
    for cam in cameras:
        name = str(cam.get("n") or cam.get("name") or "").lower()
        is_main_intersection = any(kw in name for kw in ("ленина", "60 лет", "чапаева", "победы", "самотлор"))
        if night_active and not is_main_intersection:
            # Skip 3 of 4 cycles for residential cameras at night (45 min effective interval)
            if (_watchdog_cycle_count % 4) != 0:
                continue
        filtered_cams.append(cam)

    if not filtered_cams:
        filtered_cams = cameras[:max_cameras]

    selected_cameras = sorted(
        filtered_cams,
        key=lambda cam: (
            str(cam.get("n") or cam.get("name") or ""),
            str(cam.get("s") or cam.get("stream_url") or ""),
        ),
    )[: min(max_cameras, len(filtered_cams))]

    semaphore = asyncio.Semaphore(WATCHDOG_MAX_CONCURRENCY)

    async def _scan_limited(camera: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        async with semaphore:
            return await scan_camera(camera)

    results = await asyncio.gather(
        *[_scan_limited(cam) for cam in selected_cameras],
        return_exceptions=True,
    )

    alerts = []
    for cam, result in zip(selected_cameras, results):
        try:
            if isinstance(result, Exception):
                logger.error("Watchdog cam error (%s): %s", cam.get("n"), result)
                continue
            if result:
                alert_id = await _save_alert(result)
                alerts.append({**result, "id": alert_id})

                await _send_alert_notification(bot, result, alert_id)

                logger.warning(
                    "🔴 WATCHDOG ALERT: %s at %s (conf: %.0f%%)",
                    result["event_type"],
                    result["camera_name"],
                    result["confidence"] * 100,
                )
        except Exception as e:
            logger.error("Watchdog post-process error (%s): %s", cam.get("n"), e)

    return alerts


async def run_watchdog_cycle_for_user(max_cameras: int = 10):
    """Compatibility wrapper for payment-triggered monitoring cycles."""
    return await run_watchdog_cycle(bot=None, max_cameras=max_cameras)


async def watchdog_loop(bot=None):
    """Background loop: continuously scan cameras."""
    logger.info("🐕 Camera Watchdog started (interval: %ds)", WATCHDOG_INTERVAL)
    while True:
        try:
            alerts = await run_watchdog_cycle(bot=bot)
            if alerts:
                logger.info("🐕 Watchdog cycle: %d alerts", len(alerts))
        except Exception as e:
            logger.error("Watchdog loop error: %s", e)
        await asyncio.sleep(WATCHDOG_INTERVAL)


def get_recent_alerts(limit: int = 20) -> List[Dict[str, Any]]:
    """Get recent camera alerts for API/dashboard."""
    db = SessionLocal()
    try:
        from backend.models import CameraAlert
        alerts = (
            db.query(CameraAlert)
            .order_by(CameraAlert.created_at.desc())
            .limit(limit)
            .all()
        )
        return [
            {
                "id": a.id,
                "camera_name": a.camera_name,
                "camera_lat": a.camera_lat,
                "camera_lng": a.camera_lng,
                "event_type": a.event_type,
                "description": a.description,
                "confidence": a.confidence,
                "created_at": a.created_at.isoformat() if a.created_at else None,
            }
            for a in alerts
        ]
    finally:
        db.close()
