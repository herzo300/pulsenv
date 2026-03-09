from __future__ import annotations

import tempfile
from typing import Any, Dict

from fastapi import APIRouter

from core.http_client import get_http_client
from services.zai_service import (
    CATEGORIES,
    ZAI_API_KEY,
    ZAI_BASE,
    _call_ai_api,
    _parse_json,
    analyze_complaint,
)
from services.zai_vision_service import analyze_image_with_glm4v

router = APIRouter(prefix="/ai", tags=["ai"])

_DEFAULT_CATEGORY = "Прочее"


async def _analyze_image_payload(image_b64: str, text: str) -> Dict[str, Any]:
    if not image_b64:
        return {"category": _DEFAULT_CATEGORY, "summary": "", "error": "Empty image"}

    try:
        if ZAI_API_KEY:
            prompt = (
                f"Проанализируй фото городской проблемы в Нижневартовске. {text}\n"
                f"Категории: {', '.join(CATEGORIES)}\n\n"
                "Определи:\n"
                "1. category — категория проблемы из списка выше\n"
                "2. summary — краткое описание проблемы по фото (до 150 символов)\n"
                "3. severity — 1, 2 или 3\n\n"
                'Верни только JSON: {"category":"...","summary":"...","severity":2}'
            )
            payload = {
                "model": "glm-4v",
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": (
                                        f"data:image/jpeg;base64,{image_b64}"
                                        if not image_b64.startswith("data:")
                                        else image_b64
                                    )
                                },
                            },
                        ],
                    }
                ],
                "max_tokens": 1024,
            }
            headers = {
                "Authorization": f"Bearer {ZAI_API_KEY}",
                "Content-Type": "application/json",
            }
            content = await _call_ai_api(
                f"{ZAI_BASE}/chat/completions",
                payload,
                headers,
                "Z.AI Vision",
            )
            if content:
                parsed = _parse_json(content)
                if parsed:
                    return parsed

        # Fallback: use normalized local vision helper.
        image_bytes = image_b64.split(",", 1)[1] if image_b64.startswith("data:") else image_b64
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
            import base64

            tmp.write(base64.b64decode(image_bytes))
            tmp_path = tmp.name

        try:
            result = await analyze_image_with_glm4v(tmp_path, text or None)
            return {
                "category": result.get("category", _DEFAULT_CATEGORY),
                "summary": result.get("summary") or result.get("description") or "",
                "description": result.get("description") or "",
                "address": result.get("address"),
                "severity": result.get("severity", 2),
                "location_hints": result.get("location_hints"),
                "exif_lat": result.get("exif_lat"),
                "exif_lon": result.get("exif_lon"),
                "provider": result.get("provider"),
            }
        finally:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
    except Exception as exc:
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


@router.post("/analyze")
async def analyze_text_for_complaint(request: dict):
    text = request.get("text", "")
    try:
        return await analyze_complaint(text)
    except Exception as exc:
        return {"category": _DEFAULT_CATEGORY, "summary": text[:100], "error": str(exc)}


@router.post("/analyze_image")
async def analyze_image_for_complaint(request: dict):
    image_b64 = request.get("image", "")
    text = request.get("text", "")
    return await _analyze_image_payload(image_b64, text)


@router.post("/sanitize_report")
async def sanitize_report(request: dict):
    text = str(request.get("text") or "").strip()
    image_b64 = str(request.get("image") or "").strip()
    lat = request.get("lat")
    lng = request.get("lng")
    address = str(request.get("address") or "").strip() or None

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
async def ai_proxy_analyze(request: dict):
    try:
        from services.ai_proxy_service import get_ai_proxy

        proxy = await get_ai_proxy()
        text = request.get("text", "")
        provider = request.get("provider", "zai")
        model = request.get("model", "haiku")
        return await proxy.analyze_complaint(text, provider=provider, model=model)
    except Exception as exc:
        return {
            "category": _DEFAULT_CATEGORY,
            "address": None,
            "summary": (request.get("text") or "")[:100],
            "error": str(exc),
        }


@router.get("/auth/biometrics/available")
async def biometrics_available():
    try:
        return {"available": False, "error": "Not implemented yet"}
    except Exception as exc:
        return {"available": False, "error": str(exc)}

