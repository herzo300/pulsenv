from fastapi import APIRouter

router = APIRouter(prefix="/gamification_xp", tags=["gamification_xp"])


@router.get("/ping")
def ping():
    return {"status": "ok"}
