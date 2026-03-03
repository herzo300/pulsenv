# services/Backend/routers/opendata.py
import os
from fastapi import APIRouter, Query

router = APIRouter(prefix="/opendata", tags=["opendata"])


@router.get("/summary")
async def opendata_summary():
    try:
        from services.opendata_service import get_all_summaries
        return await get_all_summaries()
    except Exception as e:
        return {"success": False, "error": str(e)}


@router.get("/full")
async def opendata_full():
    import json as _json
    try:
        if os.path.exists("opendata_full.json"):
            with open("opendata_full.json", "r", encoding="utf-8") as f:
                return _json.load(f)
        from services.opendata_service import refresh_all_datasets
        await refresh_all_datasets()
        if os.path.exists("opendata_full.json"):
            with open("opendata_full.json", "r", encoding="utf-8") as f:
                return _json.load(f)
        return {}
    except Exception as e:
        return {"error": str(e)}


@router.get("/refresh")
async def opendata_refresh():
    try:
        from services.opendata_service import refresh_all_datasets
        result = await refresh_all_datasets()
        return {"success": True, "refreshed": len(result)}
    except Exception as e:
        return {"success": False, "error": str(e)}


@router.get("/dataset/{key}")
async def opendata_dataset(
    key: str,
    rows: int = Query(20, le=100),
    page: int = Query(1, ge=1),
):
    try:
        from services.opendata_service import get_dataset_detail
        return await get_dataset_detail(key, rows=rows, page=page)
    except Exception as e:
        return {"success": False, "error": str(e)}


@router.get("/search/uk")
async def opendata_search_uk(address: str):
    try:
        from services.opendata_service import search_uk_by_address
        results = await search_uk_by_address(address)
        return {"success": True, "results": results, "count": len(results)}
    except Exception as e:
        return {"success": False, "error": str(e)}
