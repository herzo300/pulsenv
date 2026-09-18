from fastapi import APIRouter

router = APIRouter(prefix="/gamification_leaderboard", tags=["gamification_leaderboard"])


@router.get("/ping")
def ping():
    return {"status": "ok"}
