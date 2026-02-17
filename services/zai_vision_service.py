# services/zai_vision_service.py
"""Анализ изображений: OpenRouter (qwen 3.5 plus) → text fallback"""

import os
import base64
import json
import re
import logging
from typing import Dict, Any, Optional
import httpx
from core.http_client import get_http_client
from dotenv import load_dotenv
from services.ai_cache import get_cached_image, set_cached_image

load_dotenv()
logger = logging.getLogger(__name__)

# OpenRouter для анализа изображений
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
OPENROUTER_BASE = "https://openrouter.ai/api/v1"
# qwen 3.5 plus для анализа изображений
OPENROUTER_VISION_MODEL = os.getenv("OPENROUTER_VISION_MODEL", "qwen/qwen-vl-plus")

if OPENROUTER_API_KEY:
    print(f"[OK] OpenRouter vision initialized (model: {OPENROUTER_VISION_MODEL})")
else:
    print("[WARN] OPENROUTER_API_KEY не задан — анализ изображений будет использовать text fallback")

CATEGORIES = [
    "Дороги", "ЖКХ", "Освещение", "Транспорт", "Благоустройство",
    "Экология", "Животные", "Торговля", "Безопасность", "Снег/Наледь",
    "Медицина", "Образование", "Связь", "Строительство", "Парковки",
    "Социальная сфера", "Трудовое право", "Прочее", "ЧП",
    "Газоснабжение", "Водоснабжение и канализация", "Отопление",
    "Бытовой мусор", "Лифты и подъезды", "Парки и скверы",
    "Спортивные площадки", "Детские площадки",
]

VISION_PROMPT = (
    "Проанализируй фото городской проблемы в Нижневартовске.\n"
    f"Категории: {', '.join(CATEGORIES)}\n\n"
    "ОСОБОЕ ВНИМАНИЕ:\n"
    "- Если на фото автомобиль, припаркованный на тротуаре, газоне, детской площадке, "
    "пешеходном переходе, во дворе с блокировкой прохода/проезда — это категория 'Парковки', "
    "серьёзность 'высокая'. Опиши нарушение: где стоит, что блокирует.\n"
    "- Если видны номера авто — укажи в поле plates.\n\n"
    "Определи:\n"
    "1. category — категория проблемы\n"
    "2. description — описание (что видно на фото)\n"
    "3. address — адрес, если видно вывески/номера домов (или null)\n"
    "4. severity — серьёзность (низкая/средняя/высокая)\n"
    "5. has_vehicle_violation — true если авто мешает проходу/проезду\n"
    "6. plates — гос. номер авто если виден (или null)\n"
    "7. location_hints — ориентиры: названия магазинов, школ, остановок (или null)\n\n"
    'Верни ТОЛЬКО JSON: {"category":"...","description":"...","address":"...или null",'
    '"severity":"...","has_vehicle_violation":true/false,"plates":"...или null","location_hints":"...или null"}'
)


def _parse_json(text: str) -> Dict[str, Any] | None:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r'^```(?:json)?\s*', '', text)
        text = re.sub(r'\s*```$', '', text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r'\{[^{}]*\}', text, re.DOTALL)
        if m:
            try:
                return json.loads(m.group())
            except json.JSONDecodeError:
                pass
    return None


def _get_media_type(path: str) -> str:
    ext = os.path.splitext(path)[1].lower()
    return {
        '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
        '.png': 'image/png', '.gif': 'image/gif',
        '.webp': 'image/webp', '.bmp': 'image/bmp',
    }.get(ext, 'image/jpeg')


def _normalize_vision_result(result: Dict[str, Any]) -> Dict[str, Any]:
    """Нормализует результат vision AI: приводит типы, заполняет пропуски."""
    result.setdefault("has_vehicle_violation", False)
    result.setdefault("plates", None)
    result.setdefault("location_hints", None)
    # has_vehicle_violation → bool
    v = result["has_vehicle_violation"]
    if isinstance(v, str):
        result["has_vehicle_violation"] = v.lower() in ("true", "1", "yes", "да")
    elif v is None:
        result["has_vehicle_violation"] = False
    # plates
    p = result.get("plates")
    if p and isinstance(p, str) and p.lower() in ("null", "нет", "-", "не видно", ""):
        result["plates"] = None
    # location_hints
    lh = result.get("location_hints")
    if lh and isinstance(lh, str) and lh.lower() in ("null", "нет", "-", ""):
        result["location_hints"] = None
    return result


async def _openrouter_vision(image_b64: str, media_type: str, caption: str = "") -> Dict[str, Any] | None:
    """Анализ через OpenRouter (qwen 3.5 plus для изображений) с кэшированием"""
    if not OPENROUTER_API_KEY:
        return None
    
    # Проверяем кэш
    cached = get_cached_image(image_b64, caption, OPENROUTER_VISION_MODEL)
    if cached:
        logger.debug(f"✅ Using cached result for image analysis")
        return cached
    
    prompt = VISION_PROMPT
    if caption:
        prompt += f"\nДополнительно: {caption}"
    try:
        async with get_http_client(timeout=60.0, proxy=None) as client:
            r = await client.post(
                f"{OPENROUTER_BASE}/chat/completions",
                json={
                    "model": OPENROUTER_VISION_MODEL,
                    "messages": [{
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {"type": "image_url", "image_url": {
                                "url": f"data:{media_type};base64,{image_b64}"
                            }},
                        ],
                    }],
                    "max_tokens": 2048,
                },
                headers={
                    "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://github.com/soobshio/soobshio",
                    "X-Title": "Soobshio Image Analyzer",
                },
            )
        if r.status_code != 200:
            logger.error(f"OpenRouter vision error: {r.status_code} {r.text[:200]}")
            return None
        d = r.json()
        msg = d.get("choices", [{}])[0].get("message", {})
        content = msg.get("content", "")
        if not content:
            logger.warning("OpenRouter vision: empty content")
            return None
        result = _parse_json(content)
        if result:
            normalized = _normalize_vision_result(result)
            logger.info(f"✅ OpenRouter vision [{OPENROUTER_VISION_MODEL}]: {normalized.get('category')}")
            # Сохраняем в кэш
            set_cached_image(image_b64, normalized, caption, OPENROUTER_VISION_MODEL)
            return normalized
        logger.warning(f"OpenRouter vision: failed to parse JSON from: {content[:200]}")
    except Exception as e:
        logger.error(f"OpenRouter vision error: {e}")
    return None


async def analyze_image_with_glm4v(
    image_path: str, caption: Optional[str] = None
) -> Dict[str, Any]:
    """Анализ изображения: EXIF GPS + OpenRouter Vision (qwen 3.5 plus) → text fallback"""
    # Извлекаем GPS из EXIF
    exif_coords = None
    try:
        from services.exif_service import extract_gps_from_image
        exif_coords = extract_gps_from_image(image_path)
    except Exception as e:
        logger.debug(f"EXIF extraction skipped: {e}")

    try:
        with open(image_path, 'rb') as f:
            image_b64 = base64.b64encode(f.read()).decode('utf-8')
        media_type = _get_media_type(image_path)
    except Exception as e:
        logger.error(f"Image read error: {e}")
        result = {"category": "Прочее", "description": str(e), "address": None, "severity": "средняя"}
        if exif_coords:
            result["exif_lat"], result["exif_lon"] = exif_coords
        return result

    # 1. OpenRouter Vision (qwen 3.5 plus)
    result = await _openrouter_vision(image_b64, media_type, caption or "")
    if result:
        result["provider"] = f"openrouter:{OPENROUTER_VISION_MODEL}"
        if exif_coords:
            result["exif_lat"], result["exif_lon"] = exif_coords
        return result

    # 2. Text fallback (анализируем caption)
    if caption:
        from services.zai_service import analyze_complaint
        r = await analyze_complaint(caption)
        result = {
            "category": r.get("category", "Прочее"),
            "description": caption,
            "address": r.get("address"),
            "severity": "средняя",
            "provider": r.get("provider", "text_fallback"),
        }
        if exif_coords:
            result["exif_lat"], result["exif_lon"] = exif_coords
        return result

    result = {"category": "Прочее", "description": "Фото (AI недоступен)", "address": None, "severity": "средняя"}
    if exif_coords:
        result["exif_lat"], result["exif_lon"] = exif_coords
    return result


async def analyze_image_url(image_url: str, caption: Optional[str] = None) -> Dict[str, Any]:
    """Анализ изображения по URL"""
    try:
        async with get_http_client(timeout=30.0) as client:
            r = await client.get(image_url, timeout=30.0)
            r.raise_for_status()
        import tempfile
        with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as f:
            f.write(r.content)
            tmp = f.name
        result = await analyze_image_with_glm4v(tmp, caption)
        os.unlink(tmp)
        return result
    except Exception as e:
        logger.error(f"Image URL error: {e}")
        return {"category": "Прочее", "description": str(e), "address": None, "severity": "средняя"}


__all__ = ['analyze_image_with_glm4v', 'analyze_image_url']
