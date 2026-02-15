# services/zai_vision_service.py
"""Анализ изображений: Z.AI GLM-4.7V (основной) → Anthropic Vision → text fallback"""

import os
import base64
import json
import re
import logging
from typing import Dict, Any, Optional
import httpx
from core.http_client import get_http_client
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

ZAI_API_KEY = os.getenv('ZAI_API_KEY', '')
ZAI_BASE = "https://api.z.ai/api/paas/v4"
ZAI_VISION_MODEL = "GLM-4.7V"

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


async def _zai_vision(image_b64: str, media_type: str, caption: str = "") -> Dict[str, Any] | None:
    """Анализ через Z.AI GLM-4.7V (vision-модель)"""
    if not ZAI_API_KEY:
        return None
    prompt = VISION_PROMPT
    if caption:
        prompt += f"\nДополнительно: {caption}"
    try:
        async with get_http_client(timeout=60.0) as client:
            r = await client.post(
                f"{ZAI_BASE}/chat/completions",
                json={
                    "model": ZAI_VISION_MODEL,
                    "messages": [{
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {"type": "image_url", "image_url": {
                                "url": f"data:{media_type};base64,{image_b64}"
                            }},
                        ],
                    }],
                    "max_tokens": 1024,
                },
                headers={
                    "Authorization": f"Bearer {ZAI_API_KEY}",
                    "Content-Type": "application/json",
                },
            )
        if r.status_code != 200:
            logger.error(f"Z.AI vision error: {r.status_code} {r.text[:200]}")
            return None
        msg = r.json()["choices"][0]["message"]
        content = msg.get("content", "")
        if not content:
            return None
        result = _parse_json(content)
        if result:
            logger.info(f"✅ Z.AI vision [{ZAI_VISION_MODEL}]: {result.get('category')}")
            return _normalize_vision_result(result)
    except Exception as e:
        logger.error(f"Z.AI vision error: {e}")
    return None


async def _anthropic_vision(image_b64: str, media_type: str, caption: str = "") -> Dict[str, Any] | None:
    """Анализ через Anthropic Claude Vision"""
    try:
        from anthropic import Anthropic
        key = os.getenv('ANTHROPIC_API_KEY')
        if not key:
            return None
        kwargs = {"api_key": key}
        base_url = os.getenv('ANTHROPIC_BASE_URL', '')
        if base_url:
            kwargs["base_url"] = base_url
        client = Anthropic(**kwargs)
        prompt = VISION_PROMPT
        if caption:
            prompt += f"\nДополнительно: {caption}"
        response = client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=500,
            messages=[{
                "role": "user",
                "content": [
                    {"type": "image", "source": {
                        "type": "base64", "media_type": media_type, "data": image_b64,
                    }},
                    {"type": "text", "text": prompt},
                ],
            }],
        )
        content = response.content[0].text.strip()
        result = _parse_json(content)
        if result:
            logger.info(f"✅ Anthropic vision: {result.get('category')}")
            return _normalize_vision_result(result)
    except Exception as e:
        logger.error(f"Anthropic vision error: {e}")
    return None


async def analyze_image_with_glm4v(
    image_path: str, caption: Optional[str] = None
) -> Dict[str, Any]:
    """Анализ изображения: EXIF GPS + Z.AI Vision → Anthropic → text fallback"""
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

    # 1. Z.AI Vision
    result = await _zai_vision(image_b64, media_type, caption or "")
    if result:
        result["provider"] = "z.ai"
        if exif_coords:
            result["exif_lat"], result["exif_lon"] = exif_coords
        return result

    # 2. Anthropic Vision
    result = await _anthropic_vision(image_b64, media_type, caption or "")
    if result:
        result["provider"] = "anthropic"
        if exif_coords:
            result["exif_lat"], result["exif_lon"] = exif_coords
        return result

    # 3. Text fallback (анализируем caption)
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
