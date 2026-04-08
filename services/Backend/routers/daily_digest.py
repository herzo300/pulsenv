# services/Backend/routers/daily_digest.py
"""API endpoints for daily AI digest of city problems."""

from fastapi import APIRouter, Query

router = APIRouter(prefix="/api/daily-digest", tags=["daily-digest"])


@router.get("")
async def get_latest_digest():
    """Get the most recent daily digest."""
    try:
        from services.daily_digest_ai import get_latest_digest

        digest = await get_latest_digest()
        if digest:
            return {"success": True, **digest}
        return {"success": False, "error": "Дайджест ещё не сгенерирован"}
    except Exception as e:
        return {"success": False, "error": str(e)}


@router.get("/history")
async def get_digest_history(days: int = Query(7, ge=1, le=30)):
    """Get digest history for the last N days."""
    try:
        from services.daily_digest_ai import get_digest_history

        history = await get_digest_history(days)
        return {"success": True, "history": history, "count": len(history)}
    except Exception as e:
        return {"success": False, "error": str(e)}


@router.post("/generate")
async def trigger_digest_generation():
    """Manually trigger digest generation for yesterday (admin only)."""
    try:
        from services.daily_digest_ai import generate_daily_digest

        digest = await generate_daily_digest()
        return {"success": True, **digest}
    except Exception as e:
        return {"success": False, "error": str(e)}
