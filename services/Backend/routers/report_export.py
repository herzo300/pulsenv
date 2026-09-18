from fastapi import APIRouter

router = APIRouter(prefix="/report_export", tags=["report_export"])


@router.get("/ping")
def ping():
    return {"status": "ok"}
