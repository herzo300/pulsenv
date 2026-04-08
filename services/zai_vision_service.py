# services/zai_vision_service.py
"""
Image analysis: Z.AI (GLM-4V) Vision with EXIF extraction and text fallback.
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

# Config from .env — Z.AI (GLM-4V)
ZAI_API_KEY: str = os.getenv("ZAI_API_KEY", "").strip()
ZAI_BASE: str = os.getenv("ZAI_BASE_URL", "https://open.bigmodel.cn/api/paas/v4").strip().rstrip("/") or "https://open.bigmodel.cn/api/paas/v4"
ZAI_VISION_MODEL: str = os.getenv("ZAI_VISION_MODEL", "glm-4v-plus").strip() or "glm-4v-plus"

if ZAI_API_KEY:
    logger.info("🤖 Z.AI vision initialized (model: %s)", ZAI_VISION_MODEL)
else:
    logger.warning("⚠️ ZAI_API_KEY not set — image analysis will use text fallback")

# Media type mapping
_MEDIA_TYPES: dict[str, str] = {
    ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
    ".png": "image/png", ".gif": "image/gif",
    ".webp": "image/webp", ".bmp": "image/bmp",
}

VISION_PROMPT: str = (
    "Ты — глубокий аналитик городских проблем Нижневартовска. Проанализируй фото.\n"
    f"Категории: {', '.join(CATEGORIES)}\n\n"
    "ОСОБОЕ ВНИМАНИЕ:\n"
    "- Используй термин 'городская проблема' вместо 'жалоба'.\n"
    "- Если на фото автомобиль, припаркованный на тротуаре, газоне, детской площадке — это 'Парковки'.\n"
    "- ГЛУБОКИЙ АНАЛИЗ: Не используй типовые фразы. Опиши ситуацию своими словами, "
    "вникая в детали (марка авто, тип мусора, глубина ямы) и последствия.\n"
    "- АДРЕС: Указывай адрес только если уверен на 100% (видны вывески, номера домов).\n\n"
    "Определи:\n"
    "1. category — категория строго из списка\n"
    "2. description — ГЛУБОКОЕ описание ситуации своими словами (3-4 предложения)\n"
    "3. address — точный адрес (только если уверен на 100%, иначе null)\n"
    "4. severity — серьёзность (низкая/средняя/высокая)\n"
    "5. has_vehicle_violation — true если авто мешает\n"
    "6. plates — гос. номер авто если виден\n"
    "7. location_hints — ориентиры\n\n"
    'Верни ТОЛЬКО JSON: {"category":"...","description":"...","address":"...","severity":"...",'
    '"has_vehicle_violation":true/false,"plates":"...","location_hints":"..."}'
)


def _parse_json(text: str) -> Optional[Dict[str, Any]]:
    """Extract JSON from model response."""
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        # Try to find JSON block { ... }
        m = re.search(r"\{.*\}", text, re.DOTALL)
        if m:
            try:
                return json.loads(m.group())
            except json.JSONDecodeError:
                pass
    return None


def _get_media_type(path: str) -> str:
    ext = os.path.splitext(path)[1].lower()
    return _MEDIA_TYPES.get(ext, "image/jpeg")


def _verify_report_content(ai_data: Dict[str, Any], user_caption: str) -> Dict[str, Any]:
    """
    Cross-references AI vision findings with user-provided caption 
    to calculate a verification score (0.0 - 1.0).
    """
    score = 0.5  # Base score
    user_caption_lc = user_caption.lower()
    ai_desc_lc = ai_data.get("description", "").lower()
    ai_cat = ai_data.get("category", "Прочее").lower()

    # 1. Category match
    # Simple check if any keywords from user caption match category or AI description
    keywords = {
        "машина": ["парковки", "авто", "машин"],
        "авто": ["парковки", "авто", "транспорт"],
        "мусор": ["экология", "свалка", "грязь", "мусор"],
        "яма": ["дороги", "яма", "асфальт"],
        "дорог": ["дороги", "асфальт"],
        "снег": ["снег", "наледь", "сугроб"],
        "лед": ["снег", "наледь", "гололед"],
    }

    match_found = False
    for k, synonyms in keywords.items():
        if k in user_caption_lc:
            if ai_cat in synonyms or any(s in ai_desc_lc for s in synonyms):
                score += 0.3
                match_found = True
                break

    # 2. Detail check (e.g., plates mentioned by user and found by AI)
    if ai_data.get("plates") and any(char.isdigit() for char in user_caption_lc):
        score += 0.2

    # 3. Severity consistency (optional nuance)
    # If user uses caps or strong words but AI sees minor issue, reduce score? 
    # (Skip for now to avoid false negatives)

    if not match_found and len(user_caption) > 10:
        score -= 0.2

    score = max(0.0, min(1.0, score))
    
    return {
        "verification_score": round(score, 2),
        "is_verified": score >= 0.7,
        "verification_status": "verified" if score >= 0.7 else "pending_review" if score >= 0.4 else "low_confidence"
    }


def _normalize_vision_result(result: Dict[str, Any], user_caption: str = "") -> Dict[str, Any]:
    """Normalize vision AI result: coerce types, fill defaults, verify."""
    result.setdefault("has_vehicle_violation", False)
    result.setdefault("plates", None)
    result.setdefault("location_hints", None)

    # Coerce category to defined list
    cat = result.get("category", "Прочее")
    if cat not in CATEGORIES:
        result["category"] = "Прочее"

    # Coerce has_vehicle_violation to bool
    v = result["has_vehicle_violation"]
    if isinstance(v, str):
        result["has_vehicle_violation"] = v.lower() in ("true", "1", "yes", "да")
    elif v is None:
        result["has_vehicle_violation"] = False

    # Clean plates/hints
    for key in ("plates", "location_hints"):
        val = result.get(key)
        if val and isinstance(val, str) and val.lower() in ("null", "нет", "-", "не видно", ""):
            result[key] = None

    # Apply verification if caption exists
    if user_caption:
        verif = _verify_report_content(result, user_caption)
        result.update(verif)
    else:
        result.update({"verification_score": 0.5, "is_verified": False, "verification_status": "no_caption"})

    return result


async def _zai_vision(
    image_b64: str, media_type: str, caption: str = ""
) -> Optional[Dict[str, Any]]:
    """Vision analysis via Z.AI (GLM-4V)."""
    if not ZAI_API_KEY:
        return None

    payload = {
        "model": ZAI_VISION_MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": f"{VISION_PROMPT}\nДоп. описание: {caption}"},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:{media_type};base64,{image_b64}"
                        }
                    }
                ]
            }
        ],
        "temperature": 0.1
    }

    headers = {
        "Authorization": f"Bearer {ZAI_API_KEY}",
        "Content-Type": "application/json",
    }

    proxy_url = None
    from core.http_client import get_proxy_url
    try:
        proxy_url = get_proxy_url()
    except Exception:
        pass

    try:
        async with get_http_client(timeout=60.0, proxy=proxy_url) as client:
            r = await client.post(f"{ZAI_BASE}/chat/completions", json=payload, headers=headers)
            if r.status_code == 200:
                data = r.json()
                msg = data.get("choices", [{}])[0].get("message", {})
                content = msg.get("content") or ""
                if content:
                    result = _parse_json(content)
                    if result:
                        return _normalize_vision_result(result, caption)
            else:
                logger.error("Z.AI Vision HTTP %d: %s", r.status_code, r.text[:200])
    except Exception as e:
        logger.error("Z.AI Vision error: %s", e)
    return None


async def analyze_image_with_glm4v(
    image_path: str, caption: Optional[str] = None
) -> Dict[str, Any]:
    """Analyze image: EXIF GPS + Z.AI Vision → text fallback."""
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
            "description": f"Ошибка чтения файла: {e}",
            "address": None,
            "severity": "средняя",
            "verification_score": 0.0,
            "is_verified": False
        }
        if exif_coords:
            result["exif_lat"], result["exif_lon"] = exif_coords
        return result

    # 1. Z.AI Vision
    result = await _zai_vision(image_b64, media_type, caption or "")
    if result:
        result["provider"] = f"zai:{ZAI_VISION_MODEL}"
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
        # Add basic verification for text-only
        result.update({"verification_score": 0.5, "is_verified": False, "verification_status": "text_only"})
        if exif_coords:
            result["exif_lat"], result["exif_lon"] = exif_coords
        return result

    # 3. Default
    result = {
        "category": "Прочее",
        "description": "Фото (AI анализ не удался)",
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
            "description": f"Ошибка URL: {e}",
            "address": None,
            "severity": "средняя",
        }


__all__ = ["analyze_image_with_glm4v", "analyze_image_url"]
