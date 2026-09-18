from fastapi import APIRouter

router = APIRouter(prefix="/map_tiles", tags=["map_tiles"])


@router.get("/ping")
def ping():
    return {"status": "ok"}
