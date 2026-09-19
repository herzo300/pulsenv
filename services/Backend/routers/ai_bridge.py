# services/Backend/routers/ai_bridge.py — Надёжный мост к OpenRouter.
# Прямой доступ к openrouter.ai заблокирован политикой безопасности как с локальных
# IP РФ, так и с VPS. Рабочий маршрут — через Tor SOCKS (soobshio_tor:9050).
# Эндпоинт пытается: tor → прямой, кэширует последний успешный маршрут.
import os
import logging
import time
import httpx
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/ai", tags=["ai-bridge"])

OPENROUTER_KEY = os.getenv("OPENROUTER_API_KEY", "")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
TOR_PROXY = os.getenv("OPENROUTER_PROXY", "socks5://tor:9050")

# Кэш последнего рабочего маршрута: "tor" | "direct" | None
_route_state: Dict[str, Any] = {"route": None, "checked_at": 0.0}

# Бесплатный текст-фолбэк без ключа (текстовые задачи, RU-доступен напрямую)
POLLINATIONS_TEXT_URL = "https://text.pollinations.ai/openai"

# Разрешённые модели (белый список: только то, что используется приложением)
ALLOWED_MODELS = {
    "google/gemini-2.5-flash",
    "google/gemini-2.5-pro",
    "openai/gpt-5.2",
    "anthropic/claude-sonnet-4.5",
    "z-ai/glm-5.2",
    "moonshotai/kimi-k3",
    "qwen/qwen3.5-plus-02-15",
    "qwen/qwen-vl-plus",
    "deepseek/deepseek-v4-flash",
    "pollinations/openai-fast",
}


class BridgeChatRequest(BaseModel):
    model: str
    messages: List[Dict[str, Any]]
    max_tokens: Optional[int] = 1024
    temperature: Optional[float] = None


def _try_route(proxy: Optional[str], payload: dict, timeout: float) -> httpx.Response:
    headers = {
        "Authorization": f"Bearer {OPENROUTER_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://citypulse.nizhnevartovsk.ru",
        "X-Title": "City Pulse Nizhnevartovsk",
    }
    with httpx.Client(proxy=proxy, timeout=timeout, follow_redirects=True) as client:
        return client.post(OPENROUTER_URL, json=payload, headers=headers)


@router.post("/bridge")
async def openrouter_bridge(req: BridgeChatRequest, request: Request):
    """Мост к OpenRouter с автоматическим выбором маршрута (tor → direct).

    Используется мобильным приложением и сервисами, когда прямой доступ
    к openrouter.ai недоступен из сети РФ.
    """
    # Бесплатный маршрут без ключа: Pollinations (текст)
    if req.model == "pollinations/openai-fast" or not OPENROUTER_KEY:
        try:
            ppayload = {
                "model": "openai-fast",
                "messages": req.messages,
            }
            with httpx.Client(timeout=60.0) as client:
                presp = client.post(
                    POLLINATIONS_TEXT_URL,
                    json=ppayload,
                    headers={"User-Agent": "CityPulse/1.0"},
                )
                if presp.status_code == 200:
                    pdata = presp.json()
                    return {
                        "status": "ok",
                        "route": "pollinations",
                        "model": "openai-fast",
                        "choices": pdata.get("choices", []),
                        "usage": pdata.get("usage", {}),
                    }
        except Exception as e:
            logger.warning("pollinations fallback failed: %s", e)

    if not OPENROUTER_KEY:
        raise HTTPException(status_code=503, detail="OpenRouter key not configured")
    if req.model not in ALLOWED_MODELS:
        raise HTTPException(
            status_code=400,
            detail=f"Model not allowed. Allowed: {sorted(ALLOWED_MODELS)}",
        )

    payload = {
        "model": req.model,
        "messages": req.messages,
        "max_tokens": min(req.max_tokens or 1024, 4096),
    }
    if req.temperature is not None:
        payload["temperature"] = req.temperature

    # Порядок попыток: последний успешный маршрут первым
    routes = []
    last = _route_state["route"]
    if last == "direct":
        routes = [None, TOR_PROXY]
    else:
        routes = [TOR_PROXY, None]

    last_err = ""
    for route in routes:
        label = "direct" if route is None else "tor"
        try:
            resp = _try_route(route, payload, timeout=90.0)
            if resp.status_code == 200:
                _route_state["route"] = label
                _route_state["checked_at"] = time.time()
                data = resp.json()
                return {
                    "status": "ok",
                    "route": label,
                    "model": req.model,
                    "choices": data.get("choices", []),
                    "usage": data.get("usage", {}),
                }
            last_err = f"{label}: HTTP {resp.status_code}"
            logger.warning("bridge %s -> %s", label, last_err)
        except Exception as e:
            last_err = f"{label}: {type(e).__name__}"
            logger.warning("bridge route %s failed: %s", label, e)

    # Все маршруты OpenRouter упали (мёртвый ключ 401 или блок 403) —
    # спасаем текстовые запросы бесплатным Pollinations-фолбэком
    if _is_text_only(req.messages):
        try:
            ppayload = {"model": "openai-fast", "messages": req.messages}
            with httpx.Client(timeout=60.0) as client:
                presp = client.post(
                    POLLINATIONS_TEXT_URL,
                    json=ppayload,
                    headers={"User-Agent": "CityPulse/1.0"},
                )
                if presp.status_code == 200:
                    pdata = presp.json()
                    logger.info("bridge degraded to pollinations after: %s", last_err)
                    return {
                        "status": "ok",
                        "route": "pollinations-fallback",
                        "model": "openai-fast",
                        "choices": pdata.get("choices", []),
                        "usage": pdata.get("usage", {}),
                    }
        except Exception as e:
            logger.warning("pollinations last-resort failed: %s", e)

    raise HTTPException(status_code=502, detail=f"All routes failed: {last_err}")


def _is_text_only(messages: List[Dict[str, Any]]) -> bool:
    """Проверяем, что запрос не содержит изображений (текст можно деградировать)."""
    for m in messages:
        content = m.get("content")
        if isinstance(content, list):
            for part in content:
                if isinstance(part, dict) and part.get("type") == "image_url":
                    return False
    return True


@router.get("/bridge/status")
async def bridge_status():
    """Состояние моста: какой маршрут работал последним."""
    return {
        "last_route": _route_state["route"],
        "checked_at": _route_state["checked_at"],
        "tor_proxy": TOR_PROXY,
        "direct_blocked_region": True,
        "allowed_models": sorted(ALLOWED_MODELS),
    }
