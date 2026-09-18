from fastapi import APIRouter
router = APIRouter(prefix=/gamification/xp, tags=[gamification-xp])
@router.get(/ping)
def ping(): return {status: ok}
