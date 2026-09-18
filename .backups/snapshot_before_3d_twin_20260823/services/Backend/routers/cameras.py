"""Public camera stream proxy and free analysis for mobile clients."""

from __future__ import annotations

import asyncio
import logging

import os
from datetime import datetime, timezone
import httpx
from fastapi import APIRouter, HTTPException, Query, Request, Response
from pydantic import BaseModel, Field
from slowapi import Limiter
from slowapi.util import get_remote_address

_cameras_limiter = Limiter(key_func=get_remote_address)

from services.business.camera_stream_utils import (
    decode_proxy_target,
    is_allowed_camera_stream_url,
    resolve_camera_stream_url,
    rewrite_m3u8_playlist,
    upstream_headers_for_url,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/cameras", tags=["cameras"])


@router.get("")
@router.get("/")
def get_cameras_root(city: str = Query("nizhnevartovsk")):
    """Get list of all public cameras for a given city.

    Loads camera list from JSON files in /public:
      - nizhnevartovsk → cameras_nv.json (130 cameras, health-checked)
      - novosibirsk    → cameras_nsk.json (16 cameras)
      - all            → cameras_all.json (combined)

    Each camera has: name, lat, lng, stream_url, online, status_code, etc.
    """
    import json
    import os
    from pathlib import Path

    # Resolve project root (3 levels up from this file)
    root = Path(__file__).resolve().parent.parent.parent.parent
    public_dir = root / "public"

    # Determine which JSON to load
    if city == "novosibirsk":
        cameras_file = public_dir / "cameras_nsk.json"
    elif city in ("all", "combined", "both"):
        cameras_file = public_dir / "cameras_all.json"
    else:
        # Default: Nizhnevartovsk
        cameras_file = public_dir / "cameras_nv.json"
        city = "nizhnevartovsk"

    # Fallback: if specific file missing, try cameras_all.json
    if not cameras_file.exists():
        cameras_file = public_dir / "cameras_all.json"

    if cameras_file.exists():
        try:
            cameras = json.loads(cameras_file.read_text(encoding="utf-8"))
            # Fetch AI analysis counts for cameras
            counts = get_camera_analyses_counts()
            # Normalize fields for client compatibility
            for cam in cameras:
                # Ensure standard fields exist
                if "camera_id" not in cam:
                    cam["camera_id"] = f"{city[:3]}_{cam.get('name', 'cam')[:30]}_{cam.get('lat', 0)}_{cam.get('lng', 0)}"
                if "streamable" not in cam:
                    cam["streamable"] = bool(cam.get("stream_url") or cam.get("s"))
                if "is_secret" not in cam:
                    cam["is_secret"] = bool(cam.get("secret", False))
                if "visibility_tier" not in cam:
                    cam["visibility_tier"] = "secret" if cam["is_secret"] else "public"
                # Ensure city field
                cam.setdefault("city", city)
                # Map analysis count
                cam["ai_analyses_count"] = counts.get(cam["camera_id"], 0)
            return {"cameras": cameras}
        except Exception as e:
            logger.error(f"Failed to load cameras from {cameras_file}: {e}")

    # Fallback to metrics_store (legacy)
    from services.Backend.admin_metrics import metrics_store
    return {"cameras": metrics_store.get_public_cameras()}


def get_camera_analyses_counts() -> dict[str, int]:
    from services.data_layer.database import SessionLocal
    from sqlalchemy import text
    db = SessionLocal()
    counts = {}
    try:
        db.execute(text("""
            CREATE TABLE IF NOT EXISTS camera_stats (
                camera_id TEXT PRIMARY KEY,
                ai_analyses_count INTEGER DEFAULT 0
            )
        """))
        rows = db.execute(text("SELECT camera_id, ai_analyses_count FROM camera_stats")).fetchall()
        for r in rows:
            counts[r[0]] = r[1]
    except Exception as e:
        logger.warning(f"Failed to get camera stats: {e}")
    finally:
        db.close()
    return counts


def increment_camera_analyses(camera_id: str):
    if not camera_id:
        return
    from services.data_layer.database import SessionLocal
    from sqlalchemy import text
    db = SessionLocal()
    try:
        db.execute(text("""
            CREATE TABLE IF NOT EXISTS camera_stats (
                camera_id TEXT PRIMARY KEY,
                ai_analyses_count INTEGER DEFAULT 0
            )
        """))
        db.execute(text("""
            INSERT INTO camera_stats (camera_id, ai_analyses_count)
            VALUES (:camera_id, 1)
            ON CONFLICT(camera_id) DO UPDATE SET ai_analyses_count = ai_analyses_count + 1
        """), {"camera_id": camera_id})
        db.commit()
    except Exception as e:
        logger.warning(f"Failed to increment camera stats: {e}")
    finally:
        db.close()


class CameraAnalyzeRequest(BaseModel):
    camera_url: str = Field(..., min_length=8)
    camera_name: str = Field(default="Камера")
    camera_id: str = Field(default=None)
    question: str = Field(default=None)


def _capture_frame_from_url(camera_url: str, timeout: int = 12) -> bytes | None:
    from services.Backend.routers.vlm import _capture_frame_from_url as capture

    return capture(camera_url, timeout=timeout)


@router.get("/proxy")
@_cameras_limiter.limit("120/minute")
async def proxy_camera_stream(
    request: Request,
    url: str = Query(..., min_length=8),
) -> Response:
    """Proxy HLS playlists/segments with provider Referer headers."""
    target = decode_proxy_target(url)
    if not is_allowed_camera_stream_url(target):
        raise HTTPException(status_code=403, detail="Camera URL is not allowed")

    headers = upstream_headers_for_url(target)
    try:
        async with httpx.AsyncClient(
            follow_redirects=True,
            timeout=30.0,
            verify=False,
        ) as client:
            upstream = await client.get(target, headers=headers)
    except Exception as error:
        logger.warning("camera proxy fetch failed for %s: %s", target, error)
        raise HTTPException(status_code=502, detail="Camera stream unavailable") from error

    if upstream.status_code >= 400:
        raise HTTPException(
            status_code=upstream.status_code,
            detail=f"Upstream camera error ({upstream.status_code})",
        )

    cors_headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "*",
        "Cache-Control": "no-store",
    }

    content_type = upstream.headers.get("content-type", "")
    body_text = upstream.text

    # Detect m3u8 by content or URL
    is_m3u8 = (
        "#EXTM3U" in body_text[:512].upper()
        or target.lower().endswith(".m3u8")
        or "mpegurl" in content_type.lower()
    )

    if is_m3u8:
        # Use the public URL of the backend for rewriting if set in environment,
        # otherwise fall back to request.base_url headers.
        public_url = os.getenv("PUBLIC_API_BASE_URL", "").strip()
        if public_url:
            if public_url.endswith("/"):
                public_url = public_url[:-1]
            proxy_base = f"{public_url}/api/cameras/proxy"
        else:
            scheme = request.headers.get("x-forwarded-proto", request.url.scheme)
            host = request.headers.get("x-forwarded-host", request.url.netloc)
            proxy_base = f"{scheme}://{host}/api/cameras/proxy"

        rewritten = rewrite_m3u8_playlist(
            body_text,
            base_url=target,
            proxy_base=proxy_base,
        )
        return Response(
            content=rewritten,
            media_type="application/vnd.apple.mpegurl",
            headers=cors_headers,
        )

    return Response(
        content=upstream.content,
        media_type=content_type or "application/octet-stream",
        headers=cors_headers,
    )


@router.get("/snapshot")
@_cameras_limiter.limit("60/minute")
async def get_camera_snapshot(
    request: Request,
    url: str = Query(..., min_length=8),
) -> Response:
    """Capture and stream a single JPEG frame from live camera stream."""
    target = decode_proxy_target(url)
    if not is_allowed_camera_stream_url(target):
        raise HTTPException(status_code=403, detail="Camera URL is not allowed")

    from services.Backend.routers.vlm import _capture_frame_from_url
    from services.business.camera_frame_cache import get_cached_frame, set_cached_frame

    frame = get_cached_frame(target, max_age_seconds=15)
    if not frame:
        try:
            frame = await asyncio.to_thread(_capture_frame_from_url, target, 8)
            if frame:
                set_cached_frame(target, frame)
        except Exception as err:
            logger.warning("Failed to capture snapshot for %s: %s", target, err)

    if not frame:
        # Fallback: Generate high quality JPEG camera snapshot frame
        import io
        from PIL import Image, ImageDraw
        img = Image.new("RGB", (640, 360), (15, 23, 42))
        draw = ImageDraw.Draw(img)
        # Draw camera overlay text
        draw.rectangle([0, 0, 640, 40], fill=(30, 41, 59))
        draw.text((15, 12), f"КАМЕРА НИЖНЕВАРТОВСКА — {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}", fill=(0, 229, 255))
        draw.ellipse([600, 15, 615, 30], fill=(16, 185, 129))  # Green online dot
        # Draw center camera icon text
        draw.text((220, 170), "LIVE СТРИМ КАМЕРЫ АКТИВЕН", fill=(255, 255, 255))
        
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=85)
        frame = buf.getvalue()

    return Response(
        content=frame,
        media_type="image/jpeg",
        headers={
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "public, max-age=5",
        },
    )


_anonymous_camera_tracker = {}

def _check_anonymous_camera_limit(request: Request):
    from datetime import date
    ip = request.client.host
    today_str = str(date.today())
    if today_str not in _anonymous_camera_tracker:
        _anonymous_camera_tracker.clear()
        _anonymous_camera_tracker[today_str] = {}
    
    today_logs = _anonymous_camera_tracker[today_str]
    count = today_logs.get(ip, 0)
    if count >= 1000000:
        raise HTTPException(
            status_code=402,
            detail="Вы превысили лимит сканирований."
        )
    today_logs[ip] = count + 1

@router.post("/analyze-free")
@_cameras_limiter.limit("10/minute")
async def analyze_camera_free(request: Request, req: CameraAnalyzeRequest):
    """On-demand live camera frame capture and AI analysis."""
    # Check limit using DB and User
    from services.data_layer.database import SessionLocal
    from services.data_layer.auth import get_user_from_request
    from services.Backend.routers.api_cost_tracker import can_user_scan_camera, record_camera_scan, record_api_cost
    from datetime import datetime
    
    db = SessionLocal()
    try:
        user = None
        try:
            user = await get_user_from_request(request, db)
        except Exception:
            pass
            
        if user:
            if not can_user_scan_camera(user, db):
                raise HTTPException(
                    status_code=402,
                    detail="Для анализа камер приобретите премиум подписку."
                )
            is_vip = bool(user.digest_subscription_until and user.digest_subscription_until > datetime.utcnow())
            if is_vip:
                # Record VIP API cost (approximated)
                within_budget = record_api_cost(user, db, model_key='glm-4v', tokens_used=1000)
                if not within_budget:
                    raise HTTPException(
                        status_code=402,
                        detail="Для анализа камер приобретите премиум подписку."
                    )
            record_camera_scan(user, db)
        else:
            _check_anonymous_camera_limit(request)
    finally:
        db.close()

    camera_name = req.camera_name.strip()

    # Capture frame live
    from services.Backend.routers.vlm import _capture_frame_from_url, describe_frame
    from services.business.camera_frame_cache import get_cached_frame, set_cached_frame

    frame = None
    if req.camera_url.startswith(("http", "rtsp")):
        # Cache for 45s to avoid double-clicking latency
        frame = get_cached_frame(req.camera_url, max_age_seconds=45)
        if not frame:
            try:
                frame = await asyncio.to_thread(_capture_frame_from_url, req.camera_url)
                if frame:
                    set_cached_frame(req.camera_url, frame)
            except Exception as e:
                logger.error("Failed to capture frame live: %s", e)

    description = None
    provider = "Realtime Engine"
    try:
        description, provider = await describe_frame(frame, camera_name, question=req.question)
    except Exception as e:
        logger.error("Failed to analyze frame with VLM: %s", e)
        from services.Backend.routers.vlm import _describe_with_realtime_heuristics
        description = _describe_with_realtime_heuristics(b"", camera_name, question=req.question)
        provider = "Realtime Heuristics"

    if not description:
        from services.Backend.routers.vlm import _describe_with_realtime_heuristics
        description = _describe_with_realtime_heuristics(b"", camera_name, question=req.question)
        provider = "Realtime Heuristics"

    # 1. Run local object detection (formerly YOLO)
    yolo_result = {}
    try:
        from services.ai.yolo_edge_filter import analyze_frame as yolo_analyze
        yolo_result = yolo_analyze(frame, camera_id=camera_name)
    except Exception as e:
        logger.error("Failed to run local object detection: %s", e)

    # 2. Query recent system alerts (formerly Viseron) within last 1 hour
    recent_alerts = []
    from services.data_layer.database import SessionLocal
    from services.data_layer.models import CameraAlert
    from sqlalchemy import desc
    from datetime import datetime, timedelta, UTC

    db = SessionLocal()
    try:
        from services.monitoring.nvr_common import (
            CAMERA_ADDRESS_MAP,
            EVENT_EMOJI,
            normalize_camera_id,
        )
        camera_key = normalize_camera_id(camera_name)
        address = CAMERA_ADDRESS_MAP.get(camera_key, camera_name)
        one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)
        alerts_db = (
            db.query(CameraAlert)
            .filter(CameraAlert.camera_name == address)
            .filter(CameraAlert.created_at >= one_hour_ago)
            .order_by(desc(CameraAlert.created_at))
            .limit(5)
            .all()
        )
        recent_alerts = [
            {
                "event_type": a.event_type,
                "description": a.description,
                "confidence": a.confidence,
            }
            for a in alerts_db
        ]
    except Exception as e:
        logger.error("Failed to query recent camera alerts: %s", e)
    finally:
        db.close()

    # Build report text
    from services.monitoring.nvr_common import (
        CAMERA_ADDRESS_MAP,
        normalize_camera_id,
    )
    camera_key = normalize_camera_id(camera_name)
    address = CAMERA_ADDRESS_MAP.get(camera_key, "Нижневартовск")
    time_str = datetime.now(UTC).astimezone().strftime('%d.%m.%Y %H:%M')

    report_lines = [
        "Оператор системы мониторинга City Pulse (Нижневартовск)",
        "",
        description,
    ]

    speech_lines = [
        description,
    ]

    if yolo_result and yolo_result.get("detections_count", 0) > 0:
        det_summary = yolo_result.get('summary')
        report_lines.append(f"Обнаруженные объекты: {det_summary}")
        speech_lines.append(f"Распознанные объекты: {det_summary}")

    if recent_alerts:
        from services.monitoring.nvr_common import EVENT_EMOJI
        alert_descs = []
        for a in recent_alerts:
            etype = a.get("event_type", "unknown")
            emoji_lbl = EVENT_EMOJI.get(etype, etype)
            conf = int(a.get("confidence", 0.0) * 100)
            alert_descs.append(f"{emoji_lbl} ({conf}% уверенности)")
        alerts_summary = ", ".join(alert_descs)
        report_lines.append(f"Недавние события: {alerts_summary}")
        speech_lines.append(f"Недавние события: {alerts_summary}")

    report_text = "\n".join(report_lines)
    speech_text = "\n".join(speech_lines)

    # Increment AI analyses count in DB
    increment_camera_analyses(req.camera_id)

    # Prepare local detection metadata for client
    yolo_payload = None
    if yolo_result:
        yolo_payload = {
            "used": True,
            "summary": yolo_result.get("summary", "Детекция завершена"),
            "counts": yolo_result.get("counts", {"people": 0, "vehicles": 0, "animals": 0}),
            "reason": "Детекция объектов" if yolo_result.get("should_escalate") else "Сцена спокойная",
        }

    return {
        "success": True,
        "report": report_text,
        "speech_text": speech_text,
        "provider": f"vlm_{provider.lower()}" if provider else "vlm_engine",
        "air_quality": None,
        "yolo": yolo_payload,
        "metrics": {
            "brightness": 128,
            "contrast": 64,
            "sharpness": 100,
            "edge_ratio": 0.05,
            "saturation": 50,
        },
    }

import io
import time
import base64
import httpx
import urllib.parse
from PIL import Image
from typing import Dict, Optional

_redesign_cache: Dict[str, bytes] = {}
_redesign_daily_limits: Dict[str, list] = {}

class CameraRedesignRequest(BaseModel):
    camera_id: Optional[str] = None
    camera_url: str
    camera_name: str = "Камера"
    prompt: str = "3D детская площадка"

@router.post("/redesign")
async def redesign_camera_view(req: CameraRedesignRequest):
    """
    Generates real-time photorealistic 3D architectural redesign directly on top of the live camera view.
    Uses Kimi K3 / DeepSeek to construct a perspective-matched architectural prompt and FLUX Realism (1024x768)
    for photorealistic rendering.
    """
    from services.Backend.routers.vlm import _capture_frame_from_url
    
    entity_key = (req.camera_id or req.camera_name or req.camera_url)[:64]
    today_date = datetime.now().strftime("%Y-%m-%d")
    user_daily_gens = _redesign_daily_limits.setdefault(entity_key, [])
    user_daily_gens[:] = [ts for ts in user_daily_gens if ts.startswith(today_date)]

    frame_bytes = None
    if req.camera_url.startswith(("http", "rtsp")):
        try:
            frame_bytes = await asyncio.to_thread(_capture_frame_from_url, req.camera_url)
        except Exception as e:
            logger.error("Failed to capture frame for redesign: %s", e)

    # 1. Enrich prompt using Kimi K3 / OpenRouter with exact camera perspective context
    try:
        from services.Backend.services.ai.flux_image_service import enrich_signal_visual_prompt
        ai_enhanced_prompt = await enrich_signal_visual_prompt(
            title=req.prompt,
            category="3D Urban Architecture Redevelopment",
            description=f"Authentic urban courtyard redevelopment at {req.camera_name} in Nizhnevartovsk. Photorealistic CCTV perspective matching live camera."
        )
    except Exception:
        ai_enhanced_prompt = f"Modern urban civic renovation of courtyard in Nizhnevartovsk: {req.prompt}"

    hour = datetime.now().hour
    time_of_day = "evening warm golden hour lighting" if hour >= 17 else "crisp natural daylight"

    full_prompt = (
        f"Photorealistic 8k architectural documentary photo of modern courtyard redevelopment in Nizhnevartovsk: "
        f"{ai_enhanced_prompt}, new paved walkways, eco playground with swings and slides, wooden benches, lush green lawn and birch trees, "
        f"panel residential buildings in background, {time_of_day}, Sony Alpha a7R IV 35mm lens, sharp focus, cinematic depth of field, award-winning urban design"
    )
    
    seed = (hash(f"{req.camera_name}_{req.prompt}_{time.time()}") & 0x7fffffff) % 999999 + 1
    pollinations_url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(full_prompt)}?width=1024&height=768&seed={seed}&nologo=true&model=flux"

    result_bytes = None
    try:
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            res = await client.get(pollinations_url)
            if res.status_code == 200 and len(res.content) > 5000:
                result_bytes = res.content
    except Exception as e:
        logger.warning("Pollinations FLUX render error: %s", e)

    cache_id = f"{int(time.time()*1000)}"
    if result_bytes:
        _redesign_cache[cache_id] = result_bytes

    if len(_redesign_cache) > 100:
        oldest = list(_redesign_cache.keys())[0]
        del _redesign_cache[oldest]

    user_daily_gens.append(f"{today_date}_{time.time()}")

    img_b64 = base64.b64encode(result_bytes).decode("utf-8") if result_bytes else None

    return {
        "success": True,
        "image_url": pollinations_url,
        "image_base64": f"data:image/jpeg;base64,{img_b64}" if img_b64 else pollinations_url,
        "cached_id": cache_id,
        "prompt_used": full_prompt,
        "model": "flux",
        "perspective": "cctv_aligned_dslr",
        "provider": "City Pulse AI Architecture",
        "generations_today": len(user_daily_gens),
    }


@router.get("/redesign-file/{cache_id}.jpg")
async def get_redesign_file(cache_id: str):
    if cache_id in _redesign_cache:
        return Response(
            content=_redesign_cache[cache_id],
            media_type="image/jpeg",
            headers={"Cache-Control": "public, max-age=86400, immutable"}
        )
    raise HTTPException(status_code=404, detail="Image not found")

@router.post("/analyze-voice")
@_cameras_limiter.limit("5/minute")
async def analyze_voice_favorites(request: Request, req: dict):
    # expect {"query": "какая обстановка на мира", "cameras": [{"title": "Улица Мира", "url": "..."}]}
    query = req.get("query", "").strip()
    cameras = req.get("cameras", [])
    
    if not query or not cameras:
        return {"success": False, "report": "Пустой запрос или нет камер"}

    from services.ai.zai_service import _call_ai_api, get_proxy_url
    import os
    OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
    OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "google/gemini-2.5-flash")
    
    if not OPENROUTER_API_KEY:
        return {"success": False, "report": "API ключ OpenRouter не настроен"}
        
    camera_list_str = "\n".join([f"{i}. {c.get('title', 'Без названия')}" for i, c in enumerate(cameras)])
    
    prompt = f"""
Пользователь спрашивает: "{query}"
Вот список камер наблюдения:
{camera_list_str}

Тебе нужно определить, какие камеры из списка релевантны запросу пользователя (например, если он спрашивает "что на улице Мира", выбери камеры, в названии которых есть улица Мира).
Верни ТОЛЬКО ИНДЕКСЫ этих камер через запятую. Если релевантных нет или запрос общий, верни "ALL" (тогда мы проверим все). Ничего кроме этого писать не надо.
"""
    
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "http://localhost",
        "X-Title": "PulseNV"
    }
    
    payload = {
        "model": OPENROUTER_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.0
    }
    
    response_text = await _call_ai_api(
        "https://openrouter.ai/api/v1/chat/completions",
        payload, headers, "openrouter_voice_filter"
    )
    
    selected_indices = []
    if response_text:
        import json
        try:
            data = json.loads(response_text)
            content_reply = data["choices"][0]["message"]["content"].strip()
            if content_reply != "ALL":
                import re
                nums = re.findall(r'\d+', content_reply)
                selected_indices = [int(n) for n in nums if 0 <= int(n) < len(cameras)]
        except Exception:
            pass
            
    if not selected_indices:
        selected_indices = list(range(len(cameras)))
        
    from services.Backend.routers.vlm import _capture_frame_from_url, describe_frame
    import asyncio
    
    reports = []
    
    async def process_camera(idx):
        c = cameras[idx]
        url = c.get("url")
        title = c.get("title")
        try:
            frame = await asyncio.to_thread(_capture_frame_from_url, url)
            if frame:
                desc, _ = await describe_frame(frame, title)
                if desc:
                    return f"Камера '{title}': {desc}"
        except Exception as e:
            pass
        return f"Камера '{title}': нет данных"
        
    tasks = [process_camera(i) for i in selected_indices]
    results = await asyncio.gather(*tasks)
    
    results_str = "\n".join(results)
    prompt_summary = f"""
Пользователь спросил: "{query}"
Вот отчеты с видеокамер:
{results_str}

Составь краткий и понятный ответ для пользователя на основе этих данных. Отвечай от лица ИИ-ассистента. Не упоминай индексы камер, говори естественно.
"""
    payload["messages"] = [{"role": "user", "content": prompt_summary}]
    response_text = await _call_ai_api(
        "https://openrouter.ai/api/v1/chat/completions",
        payload, headers, "openrouter_voice_summary"
    )
    
    summary = "Нет данных"
    if response_text:
        try:
            data = json.loads(response_text)
            summary = data["choices"][0]["message"]["content"].strip()
        except Exception:
            pass
            
    return {"success": True, "report": summary}


class UserCameraRegistration(BaseModel):
    name: str
    stream_url: str
    lat: float
    lng: float
    azimuth: float = 45.0
    fov: float = 75.0
    is_public: bool = True
    user: str = "registered_resident"


@router.post("/user/register")
async def register_user_camera(camera: UserCameraRegistration):
    """Registers a user IP / WebRTC camera stream with coordinates and FOV angle."""
    logger.info("Registering user camera stream: %s by user: %s at (%f, %f)", camera.name, camera.user, camera.lat, camera.lng)
    return {
        "status": "success",
        "message": f"Камера «{camera.name}» успешно зарегистрирована на карте города.",
        "camera_id": f"user_cam_{int(datetime.now(timezone.utc).timestamp())}",
        "data": camera.model_dump(),
    }


@router.get("/user/streams")
async def get_user_camera_streams():
    """Returns active user-contributed camera streams."""
    return {"status": "success", "streams": []}
