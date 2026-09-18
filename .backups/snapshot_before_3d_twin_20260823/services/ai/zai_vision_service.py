# services/zai_vision_service.py
"""
Image analysis: Z.AI (GLM-4V) Vision with EXIF extraction and text fallback.
Multimodal OpenRouter fallback with Gemini 2.5 Flash, Claude 3.5 Sonnet & Qwen 2.5 VL.
"""

import base64
import json
import logging
import os
import re
from typing import Any

from services.ai.zai_service import (
    CATEGORIES,
    OPENROUTER_API_KEY,
    OPENROUTER_BASE_URL,
    OPENROUTER_MODEL,
)  # Single source of truth

logger = logging.getLogger(__name__)

# Config from .env — OpenRouter Vision
if OPENROUTER_API_KEY:
    logger.info("🤖 OpenRouter vision initialized (model: %s)", OPENROUTER_MODEL)
else:
    logger.warning("⚠️ OPENROUTER_API_KEY not set — image analysis will use text fallback")

# Media type mapping
_MEDIA_TYPES: dict[str, str] = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
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


def _parse_json(text: str) -> dict[str, Any] | None:
    """Extract JSON from model response."""
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


def _get_media_type(path: str) -> str:
    ext = os.path.splitext(path)[1].lower()
    return _MEDIA_TYPES.get(ext, "image/jpeg")


def _verify_report_content(
    ai_data: dict[str, Any], user_caption: str
) -> dict[str, Any]:
    """Cross-references AI vision findings with user-provided caption."""
    score = 0.5
    user_caption_lc = user_caption.lower()
    ai_desc_lc = ai_data.get("description", "").lower()
    ai_cat = ai_data.get("category", "Прочее").lower()

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

    if ai_data.get("plates") and any(char.isdigit() for char in user_caption_lc):
        score += 0.2

    if not match_found and len(user_caption) > 10:
        score -= 0.2

    score = max(0.0, min(1.0, score))

    return {
        "verification_score": round(score, 2),
        "is_verified": score >= 0.7,
        "verification_status": "verified"
        if score >= 0.7
        else "pending_review"
        if score >= 0.4
        else "low_confidence",
    }


def _normalize_vision_result(
    result: dict[str, Any], user_caption: str = ""
) -> dict[str, Any]:
    """Normalize vision AI result: coerce types, fill defaults, verify."""
    result.setdefault("has_vehicle_violation", False)
    result.setdefault("plates", None)
    result.setdefault("location_hints", None)

    cat = result.get("category", "Прочее")
    if cat not in CATEGORIES:
        result["category"] = "Прочее"

    v = result["has_vehicle_violation"]
    if isinstance(v, str):
        result["has_vehicle_violation"] = v.lower() in ("true", "1", "yes", "да")
    elif v is None:
        result["has_vehicle_violation"] = False

    for key in ("plates", "location_hints"):
        val = result.get(key)
        if (
            val
            and isinstance(val, str)
            and val.lower() in ("null", "нет", "-", "не видно", "")
        ):
            result[key] = None

    if user_caption:
        verif = _verify_report_content(result, user_caption)
        result.update(verif)
    else:
        result.update(
            {
                "verification_score": 0.5,
                "is_verified": False,
                "verification_status": "no_caption",
            }
        )

    return result


async def _openrouter_vision(
    image_b64: str, media_type: str, caption: str = ""
) -> dict[str, Any] | None:
    """Vision analysis via OpenRouter with multi-model fallback chain."""
    if not OPENROUTER_API_KEY:
        return None

    models_to_try = [
        OPENROUTER_MODEL or "google/gemini-2.5-flash",
        "google/gemini-2.5-flash",
        "anthropic/claude-3.5-sonnet",
        "qwen/qwen-2.5-vl-72b-instruct",
    ]
    seen = set()
    models = [m for m in models_to_try if not (m in seen or seen.add(m))]

    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/Antigravity-City/pulsenv_project",
    }

    proxy_url = None
    from core.http_client import get_proxy_url

    try:
        proxy_url = get_proxy_url()
    except Exception:
        pass

    for model in models:
        payload = {
            "model": model,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": f"{VISION_PROMPT}\nДоп. описание: {caption}",
                        },
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:{media_type};base64,{image_b64}"},
                        },
                    ],
                }
            ],
            "temperature": 0.1,
        }

        try:
            from core.http_client import get_http_client
            async with get_http_client(timeout=45.0, proxy=proxy_url) as client:
                r = await client.post(
                    f"{OPENROUTER_BASE_URL}/chat/completions", json=payload, headers=headers
                )
                if r.status_code == 200:
                    data = r.json()
                    msg = data.get("choices", [{}])[0].get("message", {})
                    content = msg.get("content") or ""
                    if content:
                        result = _parse_json(content)
                        if result:
                            logger.info("✅ OpenRouter Vision success with model %s", model)
                            return _normalize_vision_result(result, caption)
                else:
                    logger.warning("OpenRouter Vision model %s HTTP %d: %s", model, r.status_code, r.text[:150])
        except Exception as e:
            logger.warning("OpenRouter Vision model %s error: %s", model, e)
    return None


async def _zhipu_glm4v_vision(
    image_b64: str, media_type: str, caption: str = ""
) -> dict[str, Any] | None:
    """Vision analysis via official Zhipu AI GLM-4V API."""
    z_api_key = (
        os.getenv("ZAI_API_KEY")
        or os.getenv("ZHIPU_API_KEY")
        or os.getenv("GLM_API_KEY")
        or os.getenv("CURSOR_API")
    )
    if not z_api_key:
        return None

    headers = {
        "Authorization": f"Bearer {z_api_key}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": "glm-4v",
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": f"{VISION_PROMPT}\nДоп. описание: {caption}",
                    },
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{media_type};base64,{image_b64}"},
                    },
                ],
            }
        ],
        "temperature": 0.1,
    }

    proxy_url = None
    from core.http_client import get_proxy_url
    try:
        proxy_url = get_proxy_url()
    except Exception:
        pass

    try:
        from core.http_client import get_http_client
        async with get_http_client(timeout=60.0, proxy=proxy_url) as client:
            r = await client.post(
                "https://open.bigmodel.cn/api/paas/v4/chat/completions",
                json=payload,
                headers=headers,
            )
            if r.status_code == 200:
                data = r.json()
                msg = data.get("choices", [{}])[0].get("message", {})
                content = msg.get("content") or ""
                if content:
                    result = _parse_json(content)
                    if result:
                        return _normalize_vision_result(result, caption)
            else:
                logger.error("Zhipu GLM-4V Vision HTTP %d: %s", r.status_code, r.text[:200])
    except Exception as e:
        logger.error("Zhipu GLM-4V Vision error: %s", e)
    return None


async def analyze_image_with_glm4v(
    image_path: str, caption: str | None = None
) -> dict[str, Any]:
    """Analyze image: OpenRouter Fallback Chain → Z.AI Vision (GLM-4V) → text fallback."""
    try:
        with open(image_path, "rb") as f:
            image_b64 = base64.b64encode(f.read()).decode("utf-8")
        media_type = _get_media_type(image_path)
    except Exception as e:
        logger.error("Image read error: %s", e)
        return {
            "category": "Прочее",
            "description": f"Ошибка чтения файла: {e}",
            "address": None,
            "severity": "средняя",
            "verification_score": 0.0,
            "is_verified": False,
        }

    # 1. OpenRouter Vision Multi-model chain
    res = await _openrouter_vision(image_b64, media_type, caption or "")
    if res:
        return res

    # 2. Zhipu GLM-4V Direct API
    res = await _zhipu_glm4v_vision(image_b64, media_type, caption or "")
    if res:
        return res

    # Fallback response
    return {
        "category": "Прочее",
        "description": caption or "Визуальный сигнал зафиксирован объективом камеры.",
        "address": None,
        "severity": "средняя",
        "verification_score": 0.5,
        "is_verified": False,
    }
