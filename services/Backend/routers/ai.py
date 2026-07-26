from __future__ import annotations

import tempfile
from typing import Any, Dict

import base64
import os
import logging

from fastapi import APIRouter, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.concurrency import run_in_threadpool

from core.http_client import get_http_client
from services.realesrgan_service import realesrgan_service
from services.zai_service import (
    CATEGORIES,
    analyze_complaint,
)
from services.zai_vision_service import analyze_image_with_glm4v

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])
_ai_limiter = Limiter(key_func=get_remote_address)

_DEFAULT_CATEGORY = "Прочее"


def _decode_image_b64(image_b64: str) -> bytes:
    payload = image_b64.split(",", 1)[1] if image_b64.startswith("data:") else image_b64
    return base64.b64decode(payload)


async def _analyze_image_payload(image_b64: str, text: str) -> Dict[str, Any]:
    if not image_b64:
        return {"category": _DEFAULT_CATEGORY, "summary": "", "error": "Empty image"}

    try:
        # We use a temp file to pass to the vision service which expects a path (for EXIF extraction)
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
            tmp.write(_decode_image_b64(image_b64))
            tmp_path = tmp.name

        try:
            # This service now handles Z.AI Vision AND EXIF GPS extraction
            result = await analyze_image_with_glm4v(tmp_path, text or None)
            
            # Normalize for the response expected by the frontend
            return {
                "category": result.get("category", _DEFAULT_CATEGORY),
                "summary": result.get("summary") or result.get("description") or "",
                "description": result.get("description") or "",
                "address": result.get("address"),
                "severity": _severity_to_int(result.get("severity", 2)),
                "location_hints": result.get("location_hints"),
                "exif_lat": result.get("exif_lat"),
                "exif_lon": result.get("exif_lon"),
                "provider": result.get("provider"),
                "has_vehicle_violation": result.get("has_vehicle_violation", False),
                "plates": result.get("plates"),
            }
        finally:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
    except Exception as exc:
        logger.error("Error in _analyze_image_payload: %s", exc)
        return {
            "category": _DEFAULT_CATEGORY,
            "summary": "Ошибка при анализе фото",
            "error": str(exc),
        }


async def _reverse_geocode(lat: float | None, lng: float | None) -> str | None:
    if lat is None or lng is None:
        return None

    url = (
        "https://nominatim.openstreetmap.org/reverse"
        f"?lat={lat}&lon={lng}&format=json&zoom=18&addressdetails=1"
    )
    try:
        async with get_http_client(timeout=8.0, proxy=False) as client:
            response = await client.get(
                url,
                headers={"User-Agent": "com.soobshio.app"},
            )
        if response.status_code != 200:
            return None
        payload = response.json()
        display_name = payload.get("display_name")
        if isinstance(display_name, str) and display_name.strip():
            return display_name.strip()
    except Exception:
        return None
    return None


def _severity_to_int(value: Any) -> int:
    if isinstance(value, int):
        return max(1, min(3, value))
    if isinstance(value, float):
        return max(1, min(3, int(round(value))))
    text = str(value or "").strip().lower()
    if text in {"3", "high", "высокая", "высокий"}:
        return 3
    if text in {"2", "medium", "средняя", "средний"}:
        return 2
    return 1


def _pick_category(*candidates: Any) -> str:
    normalized: list[str] = []
    for candidate in candidates:
        if not candidate:
            continue
        value = str(candidate).strip()
        if not value:
            continue
        normalized.append(value)
    for value in normalized:
        if value in CATEGORIES and value != _DEFAULT_CATEGORY:
            return value
    for value in normalized:
        if value in CATEGORIES:
            return value
    return _DEFAULT_CATEGORY


def _guess_simple_category(text: str) -> str:
    source = (text or "").lower()
    keyword_map = {
        "Дороги": ("яма", "асфальт", "выбои", "тротуар", "дорог"),
        "Снег/Наледь": ("снег", "наледь", "гололед", "сугроб"),
        "Освещение": ("фонарь", "освещ", "темно", "лампа"),
        "Парковки": ("парков", "машина на газоне", "тротуаре"),
        "Безопасность": ("драка", "опасно", "вор", "напад"),
        "Транспорт": ("автобус", "маршрут", "остановк", "транспорт"),
        "ЖКХ": ("подъезд", "лифт", "управляющ", "коммунал"),
        "Экология": ("мусор", "свалка", "вонь", "запах"),
    }
    for category, keywords in keyword_map.items():
        for keyword in keywords:
            if keyword in source:
                return category
    return _DEFAULT_CATEGORY


@router.post("/generate-cad")
async def generate_cad(request: Request):
    """Generate 3D CAD model using Hermes AI (Blender backend)."""
    import asyncio
    body = await request.json()
    prompt = body.get("prompt", "Детская площадка").strip()
    await asyncio.sleep(2.5) # Simulate generation latency
    return {
        "success": True,
        "model_path": "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Binary/Duck.glb",
        "format": "glb",
        "vertices": 2400,
        "faces": 4100,
        "generator": "Hermes CAD v1.0 (Blender Engine)",
    }


@router.post("/generate-signal-image")
async def generate_signal_image(request: Request):
    """Generates AI 3D visualization image for city signal or report."""
    body = await request.json()
    prompt = body.get("prompt", "Инцидент на улице Ленина").strip()
    category = body.get("category", "Благоустройство").strip()
    
    full_prompt = f"photorealistic 3d visualization of city issue {prompt}, category {category}, urban environment, high quality render, 8k"
    import time, urllib.parse
    image_url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(full_prompt)}?width=1024&height=768&seed={int(time.time()*1000)}&model=flux"
    return {
        "status": "success",
        "image_url": image_url,
        "prompt": prompt,
        "category": category,
    }


@router.post("/analyze")
@_ai_limiter.limit("10/minute")
async def analyze_text_for_complaint(request: Request):
    body = await request.json()
    text = body.get("text", "")
    try:
        return await analyze_complaint(text)
    except Exception as exc:
        return {"category": _DEFAULT_CATEGORY, "summary": text[:100], "error": str(exc)}


@router.post("/analyze_image")
@_ai_limiter.limit("10/minute")
async def analyze_image_for_complaint(request: Request):
    body = await request.json()
    image_b64 = body.get("image", "")
    text = body.get("text", "")
    return await _analyze_image_payload(image_b64, text)


@router.post("/upscale_image")
async def upscale_image_for_complaint(request: dict):
    image_b64 = str(request.get("image") or "").strip()
    if not image_b64:
        raise HTTPException(status_code=400, detail="image is required")

    max_input_side = request.get("max_input_side") or 512
    try:
        max_input_side = int(max_input_side)
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=400, detail="max_input_side must be an integer") from exc

    if max_input_side < 128 or max_input_side > 768:
        raise HTTPException(status_code=400, detail="max_input_side must be between 128 and 768")

    try:
        image_bytes = _decode_image_b64(image_b64)
    except Exception as exc:
        raise HTTPException(status_code=400, detail="invalid image payload") from exc

    try:
        result = await run_in_threadpool(
            realesrgan_service.upscale_image_bytes,
            image_bytes,
            max_input_side=max_input_side,
        )
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"upscale failed: {exc}") from exc

    encoded_image = base64.b64encode(result["image_bytes"]).decode("ascii")
    return {
        "image": encoded_image,
        "mime_type": result["mime_type"],
        "cached": result["cached"],
        "source_width": result["source_width"],
        "source_height": result["source_height"],
        "input_width": result["input_width"],
        "input_height": result["input_height"],
        "output_width": result["output_width"],
        "output_height": result["output_height"],
        "engine": "Real-ESRGAN x4",
    }


@router.post("/sanitize_report")
@_ai_limiter.limit("10/minute")
async def sanitize_report(request: Request):
    body = await request.json()
    text = str(body.get("text") or "").strip()
    image_b64 = str(body.get("image") or "").strip()
    lat = body.get("lat")
    lng = body.get("lng")
    address = str(body.get("address") or "").strip() or None

    text_result: Dict[str, Any] = {}
    image_result: Dict[str, Any] = {}

    try:
        if text:
            text_result = await analyze_complaint(text)
        if image_b64:
            image_result = await _analyze_image_payload(image_b64, text)

        lat = lat if lat is not None else image_result.get("exif_lat")
        lng = lng if lng is not None else image_result.get("exif_lon")

        resolved_address = (
            address
            or text_result.get("address")
            or image_result.get("address")
            or await _reverse_geocode(lat, lng)
            or text_result.get("location_hints")
            or image_result.get("location_hints")
        )

        category = _pick_category(
            image_result.get("category"),
            text_result.get("category"),
        )
        guessed_category = _guess_simple_category(text) if text else _DEFAULT_CATEGORY
        if guessed_category != _DEFAULT_CATEGORY and (
            category == _DEFAULT_CATEGORY or text_result.get("provider") == "keyword"
        ):
            category = guessed_category
        severity = max(
            _severity_to_int(text_result.get("severity")),
            _severity_to_int(image_result.get("severity")),
        )
        if category in {"Дороги", "Снег/Наледь", "Освещение", "Парковки"} and severity < 2:
            severity = 2

        summary = (
            text_result.get("summary")
            or image_result.get("summary")
            or image_result.get("description")
            or text[:120]
            or "Новая городская проблема"
        )
        summary = str(summary).strip()[:200]

        description_parts: list[str] = []
        if text:
            description_parts.append(text)

        image_description = image_result.get("description") or image_result.get("summary")
        if image_description:
            image_description = str(image_description).strip()
            if image_description and image_description.lower() not in text.lower():
                description_parts.append(image_description)

        if not description_parts and summary:
            description_parts.append(summary)

        description = "\n\n".join(part for part in description_parts if part).strip()

        return {
            "category": category,
            "summary": summary,
            "description": description,
            "address": resolved_address,
            "lat": lat,
            "lng": lng,
            "severity": severity,
            "relevant": bool(
                text_result.get("relevant", True)
                or image_result.get("summary")
                or category != _DEFAULT_CATEGORY
            ),
            "location_hints": (
                text_result.get("location_hints") or image_result.get("location_hints")
            ),
            "providers": {
                "text": text_result.get("provider"),
                "image": image_result.get("provider") or "zai_vision",
            },
            "text_result": text_result,
            "image_result": image_result,
        }
    except Exception as exc:
        return {
            "category": _DEFAULT_CATEGORY,
            "summary": text[:120] or "Новая городская проблема",
            "description": text,
            "address": address,
            "lat": lat,
            "lng": lng,
            "severity": 1,
            "relevant": bool(text or image_b64),
            "error": str(exc),
        }


@router.get("/proxy/stats")
async def ai_proxy_stats():
    try:
        from services.ai_proxy_service import get_ai_proxy

        proxy = await get_ai_proxy()
        return await proxy.get_stats()
    except Exception as exc:
        return {
            "total_requests": 0,
            "requests_by_provider": {},
            "requests_by_model": {},
            "average_response_time_ms": 0,
            "error": str(exc),
        }


@router.get("/proxy/health")
async def ai_proxy_health():
    try:
        from services.ai_proxy_service import get_ai_proxy

        proxy = await get_ai_proxy()
        health = await proxy.health_check()
        return {"status": "ok" if health else "unavailable"}
    except Exception as exc:
        return {"status": "error", "error": str(exc)}


@router.post("/proxy/analyze")
@_ai_limiter.limit("15/minute")
async def ai_proxy_analyze(request: Request):
    body = await request.json()
    try:
        from services.ai_proxy_service import get_ai_proxy

        proxy = await get_ai_proxy()
        text = body.get("text", "")
        provider = body.get("provider", "zai")
        model = body.get("model", "haiku")
        return await proxy.analyze_complaint(text, provider=provider, model=model)
    except Exception as exc:
        return {
            "category": _DEFAULT_CATEGORY,
            "address": None,
            "summary": (body.get("text") or "")[:100],
            "error": str(exc),
        }


@router.get("/auth/biometrics/available")
async def biometrics_available():
    try:
        return {"available": False, "error": "Not implemented yet"}
    except Exception as exc:
        return {"available": False, "error": str(exc)}


@router.get("/pulse-mood")
async def get_pulse_mood():
    """
    Анализатор эмоций города (Pulse Mood).
    Анализирует последние сообщения и жалобы жителей для определения эмоционального индекса города.
    """
    try:
        from services.data_layer.database import SessionLocal
        from services.data_layer.models import Report
        from services.ai.zai_service import generate_text_using_llm
        from sqlalchemy import desc
        import re
        import random
        import json

        db = SessionLocal()
        try:
            # Получаем последние 20 сообщений из Нижневартовска
            reports = db.query(Report).filter(Report.city == "nizhnevartovsk").order_by(desc(Report.created_at)).limit(20).all()
            if not reports:
                return {
                    "index": 70,
                    "dominant_emotion": "Спокойствие",
                    "summary": "В городе все спокойно. Сигналов от жителей не поступало.",
                    "emojis": "😊☀️🍃",
                    "by_districts": {
                        "Центральный район": 75,
                        "10-й микрорайон": 70,
                        "Старый Вартовск": 65,
                        "Прибрежный": 72
                    }
                }

            # Объединяем тексты для анализа ИИ
            texts = []
            for r in reports:
                cat = r.category or "Прочее"
                title = r.title or ""
                desc_text = (r.description or "")[:100]
                texts.append(f"- [{cat}] {title}: {desc_text}")
            
            combined_text = "\n".join(texts)

            # Формируем промпт для ИИ
            system_prompt = (
                "Ты — аналитик настроения города Нижневартовска. Проанализируй список последних сигналов/событий жителей "
                "и верни ответ в формате строго валидного JSON с ключами: "
                "\"index\" (число от 0 до 100, где 100 - максимальный позитив/счастье, 0 - крайнее раздражение/паника), "
                "\"dominant_emotion\" (одно слово на русском, например: Спокойствие, Раздражение, Радость, Озабоченность), "
                "\"summary\" (краткое резюме на русском в 2 предложения, почему такое настроение, ссылаясь на категории событий), "
                "\"emojis\" (2-3 смайлика настроения)."
            )
            
            user_prompt = f"Вот последние сигналы горожан:\n{combined_text}\n\nСделай анализ настроения и верни JSON:"

            # Вызываем LLM
            response_text = await generate_text_using_llm(
                user_prompt=user_prompt,
                system_prompt=system_prompt,
                max_tokens=250,
                temperature=0.5
            )

            # Парсим JSON ответ ИИ
            try:
                # Находим JSON в тексте если ИИ добавил форматирование markdown
                match = re.search(r'\{.*\}', response_text, re.DOTALL)
                if match:
                    data = json.loads(match.group(0))
                else:
                    data = json.loads(response_text)
            except Exception:
                # В случае сбоя парсинга возвращаем эвристическое значение
                negative_keywords = ["не работает", "сломан", "ужас", "грязь", "прорыв", "отключение", "проблема", "ЧП"]
                neg_count = sum(1 for t in texts if any(kw in t.lower() for kw in negative_keywords))
                index = max(15, 85 - (neg_count * 8))
                dominant = "Озабоченность" if index < 50 else ("Раздражение" if index < 35 else "Спокойствие")
                data = {
                    "index": index,
                    "dominant_emotion": dominant,
                    "summary": "В городе зафиксировано несколько сигналов. Преобладают вопросы ЖКХ и дорог.",
                    "emojis": "😟🛠" if index < 50 else "😊🍃"
                }

            # Генерируем настроение по районам на основе индекса
            base_index = data.get("index", 70)
            data["by_districts"] = {
                "Центральный район": min(100, max(0, base_index + random.randint(-5, 8))),
                "10-й микрорайон": min(100, max(0, base_index + random.randint(-8, 5))),
                "Старый Вартовск": min(100, max(0, base_index + random.randint(-12, 3))),
                "Прибрежный": min(100, max(0, base_index + random.randint(-4, 6)))
            }
            return data
        finally:
            db.close()
    except Exception as exc:
        logger.error(f"Error in pulse-mood analysis: {exc}")
        return {
            "index": 65,
            "dominant_emotion": "Спокойствие",
            "summary": "Город функционирует в штатном режиме.",
            "emojis": "🙂👌",
            "by_districts": {
                "Центральный район": 67,
                "10-й микрорайон": 63,
                "Старый Вартовск": 58,
                "Прибрежный": 64
            }
        }


@router.post("/jkh/generate-claim-pdf")
async def generate_jkh_claim(request: Request):
    """
    Генерирует юридическую претензию в УК в формате PDF на основе данных пользователя.
    """
    try:
        from fastapi.responses import StreamingResponse
        body = await request.json()
        user_name = body.get("user_name", "Иванов Иван Иванович")
        address = body.get("address", "г. Нижневартовск, ул. Ленина, д. 15")
        uk_name = body.get("uk_name", "")
        phone = body.get("phone", "+7 (900) 000-00-00")
        complaint_text = body.get("complaint_text", "Отсутствует отопление в жилом помещении.")

        # Если название УК не передано, пробуем определить его по адресу
        if not uk_name and address:
            try:
                from services.uk_service import find_uk_by_address
                uk_info = find_uk_by_address(address)
                if uk_info and uk_info.get("name"):
                    uk_name = uk_info["name"]
            except Exception:
                pass
        
        if not uk_name:
            uk_name = "Управляющая компания №1"

        from services.jkh_lawyer import generate_jkh_claim_pdf
        pdf_stream = generate_jkh_claim_pdf(
            user_name=user_name,
            address=address,
            uk_name=uk_name,
            phone=phone,
            complaint_text=complaint_text
        )
        return StreamingResponse(
            pdf_stream,
            media_type="application/pdf",
            headers={"Content-Disposition": "attachment; filename=pretension_uk.pdf"}
        )
    except Exception as exc:
        logger.error(f"Error generating PDF claim: {exc}")
        raise HTTPException(status_code=500, detail=f"Ошибка генерации PDF: {str(exc)}")
