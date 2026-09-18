from fastapi import APIRouter
router = APIRouter(prefix=/reports/export, tags=[report-export])
@router.get(/ping)
def ping(): return {status: ok}
