from fastapi import APIRouter
router = APIRouter(prefix= /map/tiles, tags=[map-tiles])
@router.get(/ping)
def ping(): return {status: ok}
