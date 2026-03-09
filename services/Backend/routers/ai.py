# services/Backend/routers/ai.py
from fastapi import APIRouter
from services.zai_service import analyze_complaint

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/analyze")
async def analyze_text_for_complaint(request: dict):
    text = request.get("text", "")
    try:
        return await analyze_complaint(text)
    except Exception as e:
        return {"category": "Прочее", "summary": text[:100], "error": str(e)}

@router.post("/analyze_image")
async def analyze_image_for_complaint(request: dict):
    image_b64 = request.get("image", "")
    text = request.get("text", "")
    try:
        from services.zai_service import ZAI_API_KEY, ZAI_BASE, _call_ai_api, _parse_json, CATEGORIES
        import logging
        if not ZAI_API_KEY:
            return {"category": "Прочее", "summary": "API ключ не настроен", "error": "No ZAI_API_KEY"}
        
        prompt = (
            f"Проанализируй фото городской проблемы в Нижневартовске. {text}\n"
            f"Категории: {', '.join(CATEGORIES)}\n\n"
            "Определи:\n"
            "1. category — категория проблемы из списка выше\n"
            "2. summary — краткое описание проблемы по фото (до 150 символов)\n"
            "3. severity — 1, 2 или 3\n\n"
            'Верни ТОЛЬКО JSON: {"category":"...","summary":"...","severity":2}'
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
                                "url": f"data:image/jpeg;base64,{image_b64}" if not image_b64.startswith("data:") else image_b64
                            }
                        }
                    ]
                }
            ],
            "max_tokens": 1024,
        }
        headers = {
            "Authorization": f"Bearer {ZAI_API_KEY}",
            "Content-Type": "application/json",
        }
        content = await _call_ai_api(
            f"{ZAI_BASE}/chat/completions", payload, headers, "Z.AI Vision"
        )
        if not content:
            return {"category": "Прочее", "summary": "Не удалось распознать фото", "error": "Z.AI error"}
            
        res = _parse_json(content)
        if not res:
            return {"category": "Прочее", "summary": "Ошибка парсинга", "error": "No JSON"}
            
        return res
    except Exception as e:
        return {"category": "Прочее", "summary": "Ошибка при анализе фото", "error": str(e)}


@router.get("/proxy/stats")
async def ai_proxy_stats():
    try:
        from services.ai_proxy_service import get_ai_proxy
        proxy = await get_ai_proxy()
        return await proxy.get_stats()
    except Exception as e:
        return {
            "total_requests": 0,
            "requests_by_provider": {},
            "requests_by_model": {},
            "average_response_time_ms": 0,
            "error": str(e),
        }


@router.get("/proxy/health")
async def ai_proxy_health():
    try:
        from services.ai_proxy_service import get_ai_proxy
        proxy = await get_ai_proxy()
        health = await proxy.health_check()
        return {"status": "ok" if health else "unavailable"}
    except Exception as e:
        return {"status": "error", "error": str(e)}


@router.post("/proxy/analyze")
async def ai_proxy_analyze(request: dict):
    try:
        from services.ai_proxy_service import get_ai_proxy
        proxy = await get_ai_proxy()
        text = request.get("text", "")
        provider = request.get("provider", "zai")
        model = request.get("model", "haiku")
        return await proxy.analyze_complaint(text, provider=provider, model=model)
    except Exception as e:
        return {
            "category": "Прочее",
            "address": None,
            "summary": (request.get("text") or "")[:100],
            "error": str(e),
        }


@router.get("/auth/biometrics/available")
async def biometrics_available():
    try:
        return {"available": False, "error": "Not implemented yet"}
    except Exception as e:
        return {"available": False, "error": str(e)}
