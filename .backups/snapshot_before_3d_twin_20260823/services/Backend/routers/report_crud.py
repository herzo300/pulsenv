from fastapi import APIRouter
router = APIRouter(prefix=/reports/crud, tags=[report-crud])
@router.get(/ping)
def ping(): return {status: ok}
