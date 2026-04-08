# services/Backend/routers/visual_search.py
"""
API роутер: VIP визуальный поиск по камерам.
"""

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from ..security import require_admin_api_token

router = APIRouter(prefix="/api/visual-search", tags=["visual-search"])


class VisualSearchRequest(BaseModel):
    telegram_id: int
    description: str = ""
    image: str | None = None


class VisualSearchSubscriptionRequest(BaseModel):
    telegram_id: int
    tier: str = Field(default="standard", pattern="^(vip|standard)$")
    payment_id: str | None = None


@router.post("/search")
async def run_search(request: VisualSearchRequest):
    """Запустить визуальный поиск по камерам (требуется подписка)."""
    from services.visual_search_service import run_visual_search

    telegram_id = request.telegram_id
    description = request.description
    image_b64 = request.image
    if not description and not image_b64:
        raise HTTPException(status_code=400, detail="description or image required")

    image_bytes = None
    if image_b64:
        import base64
        try:
            payload = image_b64.split(",", 1)[1] if image_b64.startswith("data:") else image_b64
            image_bytes = base64.b64decode(payload)
        except Exception:
            raise HTTPException(status_code=400, detail="invalid image")

    result = await run_visual_search(
        telegram_id=telegram_id,
        description=description,
        reference_image_bytes=image_bytes,
    )
    return JSONResponse(content=result)


@router.get("/quota/{telegram_id}")
async def get_quota(telegram_id: int):
    """Проверить квоту пользователя."""
    from services.visual_search_service import check_quota
    return JSONResponse(content=check_quota(telegram_id))


@router.post("/subscribe")
async def subscribe(request: VisualSearchSubscriptionRequest, http_request: Request):
    """Активировать подписку (после оплаты)."""
    require_admin_api_token(http_request)
    from services.visual_search_service import activate_subscription

    sub = activate_subscription(request.telegram_id, request.tier, request.payment_id)
    return JSONResponse(content={
        "success": True,
        "tier": sub.tier,
        "searches_limit": sub.searches_limit,
        "expires_at": sub.expires_at.isoformat(),
    })


@router.get("/history/{telegram_id}")
async def search_history(telegram_id: int, limit: int = Query(5, le=20)):
    """История поисков пользователя."""
    from services.visual_search_service import get_user_search_history
    history = get_user_search_history(telegram_id, limit=limit)
    return JSONResponse(content={"history": history})


@router.get("/tiers")
async def get_tiers():
    """Получить доступные тарифы."""
    from services.visual_search_service import TIER_CONFIG
    return JSONResponse(content={"tiers": TIER_CONFIG})
