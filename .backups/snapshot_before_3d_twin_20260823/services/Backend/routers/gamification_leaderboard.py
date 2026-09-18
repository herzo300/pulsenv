from fastapi import APIRouter
router = APIRouter(prefix=/gamification/leaderboard, tags=[gamification-lb])
@router.get(/ping)
def ping(): return {status: ok}
