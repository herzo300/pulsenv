# services/zai_vision_service.py
"""
Image analysis: OpenRouter Vision (Qwen VL Plus) with text fallback.
"""

import base64
import json
import logging
import os
import re
from typing import Any, Dict, Optional

from core.http_client import get_http_client
from services.zai_service import CATEGORIES  # Single source of truth

logger = logging.getLogger(__name__)

# OpenRouter integration removed.
OPENROUTER_API_KEY: str = ""
OPENROUTER_BASE: str = ""
OPENROUTER_VISION_MODEL: str = ""

logger.info("OpenRouter vision disabled — image analysis will use text fallback")

VISION_PROMPT: str = (
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

# Media type mapping
_MEDIA_TYPES: dict[str, str] = {
    ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
    ".png": "image/png", ".gif": "image/gif",
    ".webp": "image/webp", ".bmp": "image/bmp",
}


def _parse_json(text: str) -> Optional[Dict[str, Any]]:
    """Extract JSON from model response."""
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r"\{[^{}]*\}", text, re.DOTALL)
        if m:
            try:
                return json.loads(m.group())
            except json.JSONDecodeError:
                pass
    return None


def _get_media_type(path: str) -> str:
    ext = os.path.splitext(path)[1].lower()
    return _MEDIA_TYPES.get(ext, "image/jpeg")


def _normalize_vision_result(result: Dict[str, Any]) -> Dict[str, Any]:
    """Normalize vision AI result: coerce types, fill defaults."""
    result.setdefault("has_vehicle_violation", False)
    result.setdefault("plates", None)
    result.setdefault("location_hints", None)

    # Coerce has_vehicle_violation to bool
    v = result["has_vehicle_violation"]
    if isinstance(v, str):
        result["has_vehicle_violation"] = v.lower() in ("true", "1", "yes", "да")
    elif v is None:
        result["has_vehicle_violation"] = False

    # Clean plates
    p = result.get("plates")
    if p and isinstance(p, str) and p.lower() in ("null", "нет", "-", "не видно", ""):
        result["plates"] = None

    # Clean location_hints
    lh = result.get("location_hints")
    if lh and isinstance(lh, str) and lh.lower() in ("null", "нет", "-", ""):
        result["location_hints"] = None

    return result


async def _openrouter_vision(
    image_b64: str, media_type: str, caption: str = ""
) -> Optional[Dict[str, Any]]:
    """Vision analysis via OpenRouter (REMOVED)."""
    return None


async def analyze_image_with_glm4v(
    image_path: str, caption: Optional[str] = None
) -> Dict[str, Any]:
    """Analyze image: EXIF GPS + OpenRouter Vision → text fallback."""
    # Extract GPS from EXIF
    exif_coords = None
    try:
        from services.exif_service import extract_gps_from_image
        exif_coords = extract_gps_from_image(image_path)
    except Exception as e:
        logger.debug("EXIF extraction skipped: %s", e)

    # Read and encode image
    try:
        with open(image_path, "rb") as f:
            image_b64 = base64.b64encode(f.read()).decode("utf-8")
        media_type = _get_media_type(image_path)
    except Exception as e:
        logger.error("Image read error: %s", e)
        result: Dict[str, Any] = {
            "category": "Прочее",
            "description": str(e),
            "address": None,
            "severity": "средняя",
        }
        if exif_coords:
            result["exif_lat"], result["exif_lon"] = exif_coords
        return result

    # 1. OpenRouter Vision
    result = await _openrouter_vision(image_b64, media_type, caption or "")
    if result:
        result["provider"] = f"openrouter:{OPENROUTER_VISION_MODEL}"
        if exif_coords:
            result["exif_lat"], result["exif_lon"] = exif_coords
        return result

    # 2. Text fallback (analyze caption)
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

    # 3. Default
    result = {
        "category": "Прочее",
        "description": "Фото (AI недоступен)",
        "address": None,
        "severity": "средняя",
    }
    if exif_coords:
        result["exif_lat"], result["exif_lon"] = exif_coords
    return result


async def analyze_image_url(
    image_url: str, caption: Optional[str] = None
) -> Dict[str, Any]:
    """Analyze image by URL (downloads, then analyzes)."""
    try:
        async with get_http_client(timeout=30.0) as client:
            r = await client.get(image_url, timeout=30.0)
            r.raise_for_status()
        import tempfile

        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as f:
            f.write(r.content)
            tmp = f.name
        result = await analyze_image_with_glm4v(tmp, caption)
        os.unlink(tmp)
        return result
    except Exception as e:
        logger.error("Image URL error: %s", e)
        return {
            "category": "Прочее",
            "description": str(e),
            "address": None,
            "severity": "средняя",
        }


__all__ = ["analyze_image_with_glm4v", "analyze_image_url"]
