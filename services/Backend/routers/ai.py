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
