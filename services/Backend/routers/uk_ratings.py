# services/Backend/routers/uk_ratings.py
"""
API роутер: рейтинг управляющих компаний.
"""

from fastapi import APIRouter, Query
from fastapi.responses import JSONResponse

router = APIRouter(prefix="/api/uk", tags=["uk-ratings"])


@router.get("/ratings")
async def get_ratings(limit: int = Query(50, le=100)):
    """Получить рейтинг всех УК (лучшие первые)."""
    from services.uk_rating_service import get_all_ratings
    ratings = get_all_ratings(limit=limit)
    return JSONResponse(content={"ratings": ratings, "total": len(ratings)})


@router.get("/by_coords")
async def get_uk_by_coords(lat: float, lng: float):
    """Получить УК по координатам."""
    from services.uk_service import find_uk_by_coords
    result = await find_uk_by_coords(lat, lng)
    if not result:
        return JSONResponse(status_code=404, content={"error": "УК не найдена по этому адресу"})
    return JSONResponse(content=result)


@router.get("/ratings/{uk_name}")
async def get_rating(uk_name: str):
    """Получить рейтинг конкретной УК."""
    from services.uk_rating_service import get_rating_by_name
    rating = get_rating_by_name(uk_name)
    if not rating:
        return JSONResponse(status_code=404, content={"error": "УК не найдена"})
    return JSONResponse(content=rating)


@router.post("/ratings/{uk_name}/vote")
async def vote_uk(uk_name: str, score: float = Query(..., ge=1, le=5)):
    """Оценить УК (1-5 звёзд)."""
    from services.uk_rating_service import submit_citizen_vote
    result = submit_citizen_vote(uk_name, score)
    if not result:
        return JSONResponse(status_code=400, content={"error": "Некорректная оценка"})
    return JSONResponse(content=result)


@router.post("/ratings/recalculate")
async def recalculate():
    """Пересчитать рейтинги всех УК (admin endpoint)."""
    from services.uk_rating_service import recalculate_all_ratings
    count = recalculate_all_ratings()
    return JSONResponse(content={"recalculated": count})
