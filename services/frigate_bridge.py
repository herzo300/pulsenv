# services/frigate_bridge.py
"""
Frigate → City Pulse Bridge — мост между Frigate NVR Events API и FastAPI бекендом.

Frigate обрабатывает RTSP/HLS-потоки, детектирует объекты (person, car, dog...),
и публикует события через свой HTTP API. Этот сервис:

  1. Периодически опрашивает Frigate /api/events (long-polling)
  2. Фильтрует события по городским правилам (стая собак 3+, скопление людей 6+...)
  3. Для подозрительных событий запрашивает снапшот и отправляет на LLM-анализ
  4. Создаёт Report + CameraAlert в БД и рассылает push-уведомления

Архитектура:
  cameras (HLS) → [Frigate NVR] → events API → [this bridge] → [LLM escalation] → DB + Push

Зависимости:
  - Frigate NVR (Docker) на http://frigate:5000
  - LiteLLM прокси на http://litellm:4000 (или Ollama напрямую)
  - Redis для дедупликации (опционально)
"""

import asyncio
import json
import logging
import os
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# ─── Конфигурация ───────────────────────────────────────────────────


def _running_in_docker() -> bool:
    return os.path.exists("/.dockerenv")


def _candidate_urls(
    env_name: str,
    docker_default: str,
    host_defaults: List[str],
) -> List[str]:
    explicit = (os.getenv(env_name, "") or "").strip()
    candidates: List[str] = []
    if explicit:
        candidates.append(explicit.rstrip("/"))

    defaults = [docker_default] if _running_in_docker() else host_defaults
    for value in defaults:
        normalized = value.rstrip("/")
        if normalized not in candidates:
            candidates.append(normalized)
    return candidates


FRIGATE_URLS: List[str] = _candidate_urls(
    "FRIGATE_URL",
    "http://frigate:5000",
    ["http://127.0.0.1:5000", "http://localhost:5000", "http://frigate:5000"],
)
FRIGATE_URL: str = FRIGATE_URLS[0]
FRIGATE_POLL_INTERVAL: int = int(os.getenv("FRIGATE_POLL_INTERVAL", "15"))
FRIGATE_ENABLED: bool = os.getenv("FRIGATE_ENABLED", "true").lower() == "true"

# LLM для эскалации (LiteLLM прокси → Ollama/Qwen2.5-3B)
LITELLM_URLS: List[str] = _candidate_urls(
    "LITELLM_URL",
    "http://litellm:4000",
    ["http://127.0.0.1:4000", "http://localhost:4000", "http://litellm:4000"],
)
LITELLM_URL: str = LITELLM_URLS[0]
LITELLM_MODEL: str = os.getenv("LITELLM_MODEL", "qwen-vision")
LITELLM_TIMEOUT: int = int(os.getenv("LITELLM_TIMEOUT", "30"))

# Thresholds для городского мониторинга
CROWD_THRESHOLD: int = int(os.getenv("CROWD_THRESHOLD", "6"))
DOG_PACK_THRESHOLD: int = int(os.getenv("DOG_PACK_THRESHOLD", "3"))
VEHICLE_CLUSTER_THRESHOLD: int = int(os.getenv("VEHICLE_CLUSTER_THRESHOLD", "8"))
EVENT_COOLDOWN_SEC: int = int(os.getenv("EVENT_COOLDOWN_SEC", "900"))  # 15 min

# Камеры → читаемые адреса (для Report)
CAMERA_ADDRESS_MAP: Dict[str, str] = {
    "nv_60let_10": "60 лет Октября, 10",
    "nv_chapaeva_lenina": "перекрёсток Чапаева/Ленина",
    "nv_internatsionalnaya_13": "Интернациональная, 13",
    "nv_mira_32": "Мира, 32",
    "nv_geroyev_samotlora_20": "Героев Самотлора, 20",
    "nv_prospect_pobedy_5": "пр-т Победы, 5",
    "nv_hanty_mansiyskaya_19": "Ханты-Мансийская, 19",
    "nv_ploshchad_neftyannikov": "Площадь Нефтяников",
}

# Камеры → координаты (для маркеров на карте)
CAMERA_COORDS_MAP: Dict[str, tuple] = {
    "nv_60let_10": (60.928985, 76.557381),
    "nv_chapaeva_lenina": (60.939200, 76.561500),
    "nv_internatsionalnaya_13": (60.951000, 76.582000),
    "nv_mira_32": (60.944000, 76.601000),
    "nv_geroyev_samotlora_20": (60.931000, 76.642000),
    "nv_prospect_pobedy_5": (60.938000, 76.575000),
    "nv_hanty_mansiyskaya_19": (60.935000, 76.621000),
    "nv_ploshchad_neftyannikov": (60.940500, 76.545000),
}

# Внутреннее состояние
_processed_event_ids: Set[str] = set()
_camera_cooldowns: Dict[str, float] = {}
_MAX_PROCESSED_IDS: int = 5000
_active_frigate_url: Optional[str] = None
_active_litellm_url: Optional[str] = None


# ─── Frigate HTTP API ───────────────────────────────────────────────

async def _frigate_get(path: str, timeout: float = 10.0) -> Optional[Any]:
    """GET запрос к Frigate API."""
    global _active_frigate_url
    from core.http_client import get_http_client

    for base_url in FRIGATE_URLS:
        try:
            async with get_http_client(timeout=timeout, proxy=False) as client:
                r = await client.get(f"{base_url}{path}")
                if r.status_code == 200:
                    _active_frigate_url = base_url
                    return r.json()
                logger.warning("Frigate %s via %s → HTTP %d", path, base_url, r.status_code)
        except Exception as e:
            logger.debug("Frigate API error (%s via %s): %s", path, base_url, e)
    return None


async def _frigate_get_bytes(path: str, timeout: float = 15.0) -> Optional[bytes]:
    """GET запрос к Frigate API для получения бинарных данных (снапшоты)."""
    global _active_frigate_url
    from core.http_client import get_http_client

    for base_url in FRIGATE_URLS:
        try:
            async with get_http_client(timeout=timeout, proxy=False) as client:
                r = await client.get(f"{base_url}{path}")
                if r.status_code == 200 and len(r.content) > 1000:
                    _active_frigate_url = base_url
                    return r.content
        except Exception as e:
            logger.debug("Frigate snapshot error (%s via %s): %s", path, base_url, e)
    return None


async def check_frigate_health() -> Dict[str, Any]:
    """Проверить здоровье Frigate."""
    stats = await _frigate_get("/api/stats")
    if stats:
        return {
            "healthy": True,
            "base_url": _active_frigate_url or FRIGATE_URL,
            "uptime": stats.get("uptime"),
            "cameras": {
                name: {
                    "fps": cam.get("camera_fps", 0),
                    "detection_fps": cam.get("detection_fps", 0),
                    "pid": cam.get("pid"),
                }
                for name, cam in stats.get("cameras", {}).items()
            },
            "detectors": stats.get("detectors", {}),
        }
    return {
        "healthy": False,
        "base_url": _active_frigate_url or FRIGATE_URL,
        "candidates": FRIGATE_URLS,
        "error": "Frigate not responding",
    }


# ─── Городская логика фильтрации событий ────────────────────────────

def _is_urban_alert(event: Dict[str, Any]) -> Optional[Dict[str, str]]:
    """
    Определить, является ли событие Frigate городской проблемой.

    Возвращает dict с type/label если нужна эскалация, иначе None.
    Frigate event format: {id, camera, label, top_score, ...}
    """
    label = event.get("label", "")
    score = event.get("top_score", 0)
    camera = event.get("camera", "")

    # Одиночная собака — не проблема. Стаю считаем по активным трекам.
    # Frigate не агрегирует — это делаем мы в _aggregate_camera_objects()
    if label == "dog" and score >= 0.45:
        return {"type": "animals", "label": "Бродячая собака обнаружена"}

    if label == "person" and score >= 0.6:
        return {"type": "crowd_check", "label": "Человек обнаружен (проверка скопления)"}

    return None


async def _aggregate_camera_objects(camera: str) -> Dict[str, int]:
    """
    Получить текущие активные объекты на конкретной камере.
    Frigate API: GET /api/<camera>/objects
    """
    data = await _frigate_get(f"/api/{camera}")
    if not data:
        return {}

    # Frigate config endpoint возвращает tracked objects
    objects_data = await _frigate_get(f"/api/events?cameras={camera}&in_progress=1&limit=50")
    if not objects_data:
        return {}

    counts: Dict[str, int] = {}
    for evt in objects_data:
        lbl = evt.get("label", "unknown")
        counts[lbl] = counts.get(lbl, 0) + 1

    return counts


async def _check_urban_thresholds(camera: str, trigger_label: str) -> Optional[Dict[str, Any]]:
    """
    Проверить, превышены ли городские пороги для данной камеры.
    Агрегирует все активные объекты и сравнивает с порогами.
    """
    counts = await _aggregate_camera_objects(camera)
    if not counts:
        return None

    alerts = []

    dog_count = counts.get("dog", 0)
    if dog_count >= DOG_PACK_THRESHOLD:
        alerts.append({
            "event_type": "animals",
            "description": f"Стая бродячих собак ({dog_count} особей) обнаружена камерой",
            "confidence": 0.8,
            "severity": 3,
        })

    person_count = counts.get("person", 0)
    if person_count >= CROWD_THRESHOLD:
        alerts.append({
            "event_type": "crowd",
            "description": f"Скопление людей ({person_count} чел.) — возможное ЧП или массовое мероприятие",
            "confidence": 0.7,
            "severity": 2,
        })

    vehicle_count = sum(counts.get(v, 0) for v in ("car", "truck", "bus", "motorcycle"))
    if vehicle_count >= VEHICLE_CLUSTER_THRESHOLD:
        alerts.append({
            "event_type": "traffic",
            "description": f"Плотный трафик ({vehicle_count} ТС) — возможный затор или ДТП",
            "confidence": 0.6,
            "severity": 2,
        })

    if alerts:
        # Возвращаем самый серьёзный
        alerts.sort(key=lambda a: a["severity"], reverse=True)
        return alerts[0]

    return None


# ─── LLM эскалация (Ollama / Qwen2.5-VL через LiteLLM) ─────────────

async def _llm_analyze_snapshot(snapshot_bytes: bytes, camera_name: str) -> Optional[Dict[str, Any]]:
    """
    Отправить снапшот на локальный VLM для глубокого анализа.
    Используется только при эскалации — не для каждого кадра!
    """
    import base64

    image_b64 = base64.b64encode(snapshot_bytes).decode("utf-8")

    prompt = (
        f"Ты — система видеонаблюдения города Нижневартовск. Камера: {camera_name}. "
        "Проанализируй снимок. Найди проблемы:\n"
        "1. dump — мусорная свалка\n"
        "2. accident — ДТП\n"
        "3. flood — затопление\n"
        "4. smoke — задымление/пожар\n"
        "5. animals — стая бродячих собак (3+)\n"
        "6. crowd — толпа, массовая драка\n"
        "7. none — всё нормально\n\n"
        'Верни JSON: {"event_type":"тип","confidence":0.0-1.0,"description":"описание"}'
    )

    payload = {
        "model": LITELLM_MODEL,
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
        "max_tokens": 200,
    }

    global _active_litellm_url
    from core.http_client import get_http_client

    for base_url in LITELLM_URLS:
        try:
            async with get_http_client(timeout=float(LITELLM_TIMEOUT), proxy=False) as client:
                r = await client.post(
                    f"{base_url}/v1/chat/completions",
                    json=payload,
                    headers={"Content-Type": "application/json"},
                )
                if r.status_code == 200:
                    data = r.json()
                    content = (
                        data.get("choices", [{}])[0]
                        .get("message", {})
                        .get("content", "")
                    )
                    if content:
                        _active_litellm_url = base_url
                        return _parse_vlm_json(content)
                else:
                    logger.warning("LiteLLM %s → HTTP %d", base_url, r.status_code)
        except Exception as e:
            logger.debug("LiteLLM VLM error via %s: %s", base_url, e)

    return None


def _parse_vlm_json(text: str) -> Optional[Dict[str, Any]]:
    """Parse JSON from VLM response."""
    import re
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


# ─── Сохранение алертов ─────────────────────────────────────────────

async def _save_frigate_alert(camera: str, alert: Dict[str, Any], snapshot: Optional[bytes] = None) -> int:
    """Сохранить алерт в БД и создать маркер на карте."""
    from backend.database import SessionLocal
    from backend.models import CameraAlert, Report

    coords = CAMERA_COORDS_MAP.get(camera, (0, 0))
    address = CAMERA_ADDRESS_MAP.get(camera, camera)

    CAT_MAP = {
        "dump": "Бытовой мусор",
        "accident": "ДТП",
        "flood": "ЖКХ",
        "smoke": "Безопасность",
        "animals": "Животные",
        "crowd": "Безопасность",
        "traffic": "Транспорт",
    }

    TITLE_MAP = {
        "dump": "Frigate AI: Свалка мусора",
        "accident": "Frigate AI: ДТП",
        "flood": "Frigate AI: Затопление",
        "smoke": "Frigate AI: Задымление",
        "animals": "Frigate AI: Стая собак",
        "crowd": "Frigate AI: Скопление людей",
        "traffic": "Frigate AI: Затор на дороге",
    }

    event_type = alert.get("event_type", "unknown")
    confidence = alert.get("confidence", 0.0)

    db = SessionLocal()
    try:
        # CameraAlert (техническая запись)
        db_alert = CameraAlert(
            camera_name=address,
            camera_lat=coords[0],
            camera_lng=coords[1],
            event_type=event_type,
            description=alert.get("description", ""),
            confidence=confidence,
        )
        db.add(db_alert)

        # Report (маркер на карте) — только если координаты известны и адрес 100%
        if coords[0] != 0 and coords[1] != 0 and address:
            report = Report(
                title=TITLE_MAP.get(event_type, f"Frigate AI: {event_type}"),
                description=(
                    f"🤖 Frigate NVR ({int(confidence * 100)}%):\n"
                    f"{alert.get('description', '')}\n"
                    f"Камера: {address}"
                ),
                lat=coords[0],
                lng=coords[1],
                address=address,
                category=CAT_MAP.get(event_type, "Прочее"),
                source="frigate_ai",
                status="pending",
            )
            db.add(report)

        db.commit()
        db.refresh(db_alert)
        return db_alert.id
    finally:
        db.close()


async def _send_frigate_notification(bot, camera: str, alert: Dict[str, Any],
                                      alert_id: int, snapshot: Optional[bytes] = None):
    """Push-уведомление через Telegram и geo-подписчикам."""
    EVENT_EMOJI = {
        "dump": "🗑️ Свалка",
        "accident": "🚗 ДТП",
        "flood": "💧 Затопление",
        "smoke": "🔥 Задымление",
        "animals": "🐕 Стая собак",
        "crowd": "👥 Скопление людей",
        "traffic": "🚦 Затор",
    }

    address = CAMERA_ADDRESS_MAP.get(camera, camera)
    event_type = alert.get("event_type", "?")
    event_label = EVENT_EMOJI.get(event_type, f"⚠️ {event_type}")
    conf_pct = int(alert.get("confidence", 0) * 100)

    text = (
        f"🔴 *Frigate Alert #{alert_id}*\n\n"
        f"{event_label}\n"
        f"📹 {address}\n"
    )
    if alert.get("description"):
        text += f"📝 {alert['description'][:200]}\n"
    text += f"🎯 Уверенность: {conf_pct}%\n"

    coords = CAMERA_COORDS_MAP.get(camera)
    if coords:
        text += f"📍 {coords[0]:.4f}, {coords[1]:.4f}\n"

    from core.config import TARGET_CHANNEL
    from services.push_notification_service import send_telegram_message, send_telegram_photo
    try:
        if snapshot:
            await send_telegram_photo(
                TARGET_CHANNEL,
                snapshot,
                filename="frigate_incident.jpg",
                caption=text,
                parse_mode=None,
            )
        else:
            await send_telegram_message(TARGET_CHANNEL, text, parse_mode=None)
    except Exception as e:
        logger.error("Frigate alert publish error: %s", e)

    # Geo push
    if coords:
        try:
            from services.push_notification_service import notify_subscribers
            is_emergency = event_type in ("smoke", "animals", "accident")
            await notify_subscribers(
                lat=coords[0],
                lng=coords[1],
                category="Безопасность",
                summary=f"[Frigate] {event_label}: {alert.get('description', '')}",
                address=address,
                report_id=None,
                is_emergency=is_emergency,
                photo=snapshot,
            )
        except Exception as e:
            logger.debug("Frigate push error: %s", e)


# ─── Основной цикл опроса Frigate ──────────────────────────────────

async def _process_event(event: Dict[str, Any], bot=None):
    """Обработать одно событие Frigate."""
    event_id = event.get("id", "")
    camera = event.get("camera", "")
    label = event.get("label", "")

    # Дедупликация
    if event_id in _processed_event_ids:
        return
    _processed_event_ids.add(event_id)

    # FIFO для ограничения памяти
    if len(_processed_event_ids) > _MAX_PROCESSED_IDS:
        oldest = list(_processed_event_ids)[:1000]
        for old_id in oldest:
            _processed_event_ids.discard(old_id)

    # Cooldown камеры (не чаще чем раз в EVENT_COOLDOWN_SEC)
    now = time.time()
    cooldown_key = f"{camera}:{label}"
    if cooldown_key in _camera_cooldowns:
        if now - _camera_cooldowns[cooldown_key] < EVENT_COOLDOWN_SEC:
            logger.debug("Cooldown skip: %s on %s", label, camera)
            return
    _camera_cooldowns[cooldown_key] = now

    # Проверяем городские пороги (агрегация)
    urban_alert = await _check_urban_thresholds(camera, label)
    if not urban_alert:
        logger.debug("No urban threshold exceeded for %s on %s", label, camera)
        return

    # Получаем снапшот для LLM-анализа
    snapshot = await _frigate_get_bytes(f"/api/events/{event_id}/snapshot.jpg")

    # Если VLM доступен — делаем глубокий анализ
    llm_result = None
    if snapshot:
        llm_result = await _llm_analyze_snapshot(
            snapshot,
            CAMERA_ADDRESS_MAP.get(camera, camera),
        )

    # Финальный алерт: берём LLM результат или городской порог
    final_alert = llm_result if llm_result else urban_alert

    event_type = final_alert.get("event_type", "none")
    confidence = final_alert.get("confidence", 0.0)

    if event_type == "none" or confidence < 0.5:
        return

    # Сохраняем и рассылаем
    alert_id = await _save_frigate_alert(camera, final_alert, snapshot)

    logger.warning(
        "🔴 FRIGATE ALERT #%d: %s at %s (conf: %.0f%%)",
        alert_id, event_type,
        CAMERA_ADDRESS_MAP.get(camera, camera),
        confidence * 100,
    )

    await _send_frigate_notification(bot, camera, final_alert, alert_id, snapshot)


async def frigate_event_loop(bot=None):
    """
    Основной цикл: опрашивает Frigate Events API, фильтрует,
    эскалирует на LLM, создаёт алерты.
    """
    if not FRIGATE_ENABLED:
        logger.info("Frigate bridge disabled (FRIGATE_ENABLED=false)")
        return

    logger.info(
        "🎥 Frigate bridge started — polling %s every %ds",
        FRIGATE_URL, FRIGATE_POLL_INTERVAL,
    )

    # Стартовый health check
    health = await check_frigate_health()
    if health.get("healthy"):
        logger.info("✅ Frigate healthy: %s", json.dumps(health, indent=2))
    else:
        logger.warning("⚠️ Frigate not available, will retry: %s", health)

    last_event_time = time.time() - 60  # Начинаем с событий за последнюю минуту

    while True:
        try:
            # Получаем недавние события
            events = await _frigate_get(
                f"/api/events?after={last_event_time:.0f}&limit=50"
            )

            if events and isinstance(events, list):
                for event in events:
                    try:
                        await _process_event(event, bot=bot)
                    except Exception as e:
                        logger.error("Event processing error: %s", e)

                # Обновляем timestamp
                if events:
                    latest_ts = max(
                        evt.get("start_time", 0) for evt in events
                    )
                    if latest_ts > last_event_time:
                        last_event_time = latest_ts

        except Exception as e:
            logger.error("Frigate poll error: %s", e)

        await asyncio.sleep(FRIGATE_POLL_INTERVAL)


# ─── Fallback: если Frigate недоступен → старый watchdog ────────────

async def smart_watchdog_loop(bot=None):
    """
    Интеллектуальный watchdog: пытается использовать Frigate,
    при недоступности — откат на старый camera_watchdog_service.
    """
    logger.info("🧠 Smart Watchdog starting (Frigate-first, fallback to legacy)...")

    # Проверяем Frigate
    health = await check_frigate_health()

    if health.get("healthy"):
        logger.info("✅ Frigate доступен — используем Frigate bridge")
        await frigate_event_loop(bot=bot)
    else:
        logger.warning("⚠️ Frigate недоступен — используем legacy watchdog")
        from services.camera_watchdog_service import watchdog_loop
        await watchdog_loop(bot=bot)


# ─── API для роутера (статус / ручной запуск) ───────────────────────

async def get_bridge_status() -> Dict[str, Any]:
    """Статус Frigate bridge для админ-панели."""
    health = await check_frigate_health()
    return {
        "frigate_enabled": FRIGATE_ENABLED,
        "frigate_url": FRIGATE_URL,
        "frigate_candidates": FRIGATE_URLS,
        "frigate_health": health,
        "active_frigate_url": _active_frigate_url,
        "litellm_url": LITELLM_URL,
        "litellm_candidates": LITELLM_URLS,
        "active_litellm_url": _active_litellm_url,
        "litellm_model": LITELLM_MODEL,
        "poll_interval": FRIGATE_POLL_INTERVAL,
        "event_cooldown": EVENT_COOLDOWN_SEC,
        "processed_events": len(_processed_event_ids),
        "active_cooldowns": len(_camera_cooldowns),
        "thresholds": {
            "crowd": CROWD_THRESHOLD,
            "dog_pack": DOG_PACK_THRESHOLD,
            "vehicle_cluster": VEHICLE_CLUSTER_THRESHOLD,
        },
    }
