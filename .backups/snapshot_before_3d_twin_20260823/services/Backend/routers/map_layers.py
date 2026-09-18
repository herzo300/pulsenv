from fastapi import APIRouter
router = APIRouter(prefix=/map/layers, tags=[map-layers])
@router.get(/ping)
def ping(): return {status: ok}
