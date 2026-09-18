"""
Fetch open datasets from data.n-vartovsk.ru (no API key required for /opendata/{id}/data.json).
Optional NV_OPENDATA_API_KEY enables full pagination via /api/v1/.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import httpx

logger = logging.getLogger(__name__)

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = PROJECT_ROOT / "opendata_full.json"

OPENDATA_BASE = "https://data.n-vartovsk.ru"
DS_PREFIX = "8603032896"
USER_AGENT = "PulsGoroda/2.0 OpenDataSync"
REQUEST_TIMEOUT = 45.0

NV_OPENDATA_API_KEY = os.getenv("NV_OPENDATA_API_KEY", "").strip()

# Datasets used by infographic + city dashboard (catalog + legacy identifiers)
INFOGRAPHIC_DATASET_KEYS = [
    "topnameboys",
    "topnamegirls",
    "averagesalary",
    "roadgasstationprice",
    "roadgasstation",
    "demography",
    "busroute",
    "busstation",
    "roadworks",
    "uchou",
    "uchdou",
    "uchgkhservices",
    "uchsportsection",
    "uchsporttrainers",
    "uchculture",
    "uchcultureclubs",
    "placespk",
    "wastecollection",
    "buildreestr",
    "buildpermission",
    "buildlist",
    "propertyregisterrealestate",
    "propertyregistermovableproperty",
    "propertyregisterlands",
    "dostupnayasreda",
    "sitenews",
    "budgetinfo",
    "budgetbulletin",
    "listoumd",
    "agreementsek",
    "agreementsgchp",
    "tarif",
    "landplotsreestr",
    "inforent",
    "infoprivatization",
    "mspsupport",
    "listcommunicationequipment",
]


def _dataset_id(key: str) -> str:
    return f"{DS_PREFIX}-{key}"


async def _fetch_catalog(client: httpx.AsyncClient) -> list[dict[str, Any]]:
    resp = await client.get(f"{OPENDATA_BASE}/opendata/list.json")
    resp.raise_for_status()
    payload = json.loads(resp.content.decode("utf-8-sig"))
    meta = payload.get("meta") or []
    return meta if isinstance(meta, list) else []


async def _fetch_public_json(
    client: httpx.AsyncClient, dataset_id: str
) -> dict[str, Any]:
    url = f"{OPENDATA_BASE}/opendata/{dataset_id}/data.json"
    resp = await client.get(url)
    if resp.status_code != 200:
        return {"rows": [], "total": 0, "error": resp.status_code}
    data = resp.json()
    rows = data.get("rows") or []
    total = data.get("total")
    if total is None and isinstance(data.get("meta"), dict):
        total = data["meta"].get("total")
    return {"rows": rows, "total": int(total or len(rows))}


async def _fetch_api_pages(
    client: httpx.AsyncClient, dataset_id: str, max_pages: int = 30
) -> list[dict[str, Any]]:
    if not NV_OPENDATA_API_KEY:
        return []

    all_rows: list[dict] = []
    page = 1
    while page <= max_pages:
        url = (
            f"{OPENDATA_BASE}/api/v1/{dataset_id}/data"
            f"?api_key={NV_OPENDATA_API_KEY}&ROWS=500&PAGE={page}"
        )
        resp = await client.get(url)
        if resp.status_code != 200:
            break
        payload = resp.json().get("RESULT", {})
        rows = payload.get("ROWS", [])
        if not rows:
            break
        all_rows.extend(rows)
        total_pages = payload.get("META", {}).get("PAGE_TOTAL", 1)
        if page >= total_pages:
            break
        page += 1
    return all_rows


async def _fetch_dataset(
    client: httpx.AsyncClient, key: str, title: str = ""
) -> dict[str, Any]:
    dataset_id = _dataset_id(key)
    public = await _fetch_public_json(client, dataset_id)
    rows = public.get("rows") or []
    total = int(public.get("total") or len(rows))

    if NV_OPENDATA_API_KEY:
        api_rows = await _fetch_api_pages(client, dataset_id)
        if len(api_rows) > len(rows):
            rows = api_rows
            total = max(total, len(rows))

    return {
        "id": dataset_id,
        "title": title,
        "rows": rows,
        "total": total,
        "sample_size": len(rows),
    }


async def update_opendata(
    output_path: Path | str | None = None,
    *,
    keys: list[str] | None = None,
) -> dict[str, Any]:
    """Download datasets and save opendata_full.json."""
    output_path = Path(output_path or DEFAULT_OUTPUT)
    keys = keys or INFOGRAPHIC_DATASET_KEYS

    titles: dict[str, str] = {}
    async with httpx.AsyncClient(
        follow_redirects=True,
        timeout=REQUEST_TIMEOUT,
        headers={"User-Agent": USER_AGENT},
        limits=httpx.Limits(max_connections=8),
    ) as client:
        try:
            catalog = await _fetch_catalog(client)
            for item in catalog:
                ident = str(item.get("identifier", ""))
                if "-" in ident:
                    key = ident.split("-", 1)[1]
                    titles[key] = str(item.get("title") or key)
        except Exception as exc:
            logger.warning("Catalog fetch failed: %s", exc)
            catalog = []

        sem = asyncio.Semaphore(6)

        async def _one(key: str) -> tuple[str, dict[str, Any]]:
            async with sem:
                try:
                    data = await _fetch_dataset(client, key, titles.get(key, key))
                    logger.info("  %s: %d rows (total %d)", key, data["sample_size"], data["total"])
                    return key, data
                except Exception as exc:
                    logger.error("  %s failed: %s", key, exc)
                    return key, {"id": _dataset_id(key), "rows": [], "total": 0, "error": str(exc)}

        pairs = await asyncio.gather(*[_one(k) for k in keys])
        datasets = dict(pairs)

    result: dict[str, Any] = {
        "_meta": {
            "updated_at": datetime.now(UTC).isoformat(),
            "source": OPENDATA_BASE,
            "catalog_count": len(catalog),
            "datasets_fetched": len(datasets),
            "datasets_with_data": sum(1 for v in datasets.values() if v.get("total")),
            "api_key_used": bool(NV_OPENDATA_API_KEY),
        },
        **datasets,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        json.dump(result, handle, ensure_ascii=False, indent=2)

    logger.info(
        "Saved %s (%d datasets, %d non-empty)",
        output_path,
        len(datasets),
        result["_meta"]["datasets_with_data"],
    )
    return result


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    asyncio.run(update_opendata())
