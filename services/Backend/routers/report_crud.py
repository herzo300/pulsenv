from fastapi import APIRouter

router = APIRouter(prefix="/report_crud", tags=["report_crud"])


@router.get("/ping")
def ping():
    return {"status": "ok"}
