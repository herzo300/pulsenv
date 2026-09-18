#!/usr/bin/env python3
"""Download and normalize UK catalog (listoumd) from n-vartovsk opendata."""

from __future__ import annotations

import asyncio
import json
import os
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

OUTPUT = ROOT / "data" / "uk_catalog.json"
DATASET_ID = "8603032896-listoumd"


def _group_rows(rows: list[dict]) -> list[dict]:
    """Merge flat opendata rows (one street per row) into UK records."""
    grouped: dict[str, dict] = {}
    streets_by_key: dict[str, set[str]] = defaultdict(set)

    for row in rows:
        if not isinstance(row, dict):
            continue
        key = str(row.get("GID") or row.get("INN") or row.get("TITLESM") or row.get("TITLE") or "")
        if not key:
            continue
        if key not in grouped:
            grouped[key] = dict(row)
            grouped[key]["MKD"] = []
        street = row.get("MKD")
        if isinstance(street, str) and street.strip():
            streets_by_key[key].add(street.strip())
        elif isinstance(street, list):
            for block in street:
                if isinstance(block, dict):
                    s = str(block.get("STREET") or "").strip()
                    if s:
                        streets_by_key[key].add(s)
                elif isinstance(block, str) and block.strip():
                    streets_by_key[key].add(block.strip())

    result: list[dict] = []
    for key, uk in grouped.items():
        uk["MKD"] = [{"STREET": s, "BUILDINGS": []} for s in sorted(streets_by_key[key])]
        if uk.get("ADDRESS") and not uk.get("ADR"):
            uk["ADR"] = uk["ADDRESS"]
        if uk.get("WORK") and not uk.get("WORK_TIME"):
            uk["WORK_TIME"] = uk["WORK"]
        result.append(uk)

    result.sort(key=lambda row: str(row.get("TITLESM") or row.get("TITLE") or ""))
    return result


async def _fetch_all_rows() -> list[dict]:
    import httpx

    referer = f"https://data.n-vartovsk.ru/opendata/{DATASET_ID}/"
    headers = {
        "Accept": "application/json",
        "Referer": referer,
        "User-Agent": "PulsGoroda/2.0 UKSync",
    }
    rows: list[dict] = []

    async with httpx.AsyncClient(timeout=60.0, follow_redirects=True) as client:
        first = await client.get(
            f"https://data.n-vartovsk.ru/api/v1/{DATASET_ID}/data",
            headers=headers,
        )
        first.raise_for_status()
        result = first.json().get("RESULT") or {}
        meta = result.get("META") or {}
        rows.extend(result.get("ROWS") or [])
        total_pages = int(meta.get("PAGE_TOTAL") or 1)

        for page in range(2, total_pages + 1):
            resp = await client.get(
                f"https://data.n-vartovsk.ru/api/v1/{DATASET_ID}/data?page={page}",
                headers=headers,
            )
            resp.raise_for_status()
            rows.extend((resp.json().get("RESULT") or {}).get("ROWS") or [])

        if len(rows) < int(meta.get("ROWS_TOTAL") or len(rows)):
            from services.opendata_updater import NV_OPENDATA_API_KEY, _fetch_api_pages, _fetch_public_json

            if NV_OPENDATA_API_KEY:
                api_rows = await _fetch_api_pages(client, DATASET_ID)
                if len(api_rows) > len(rows):
                    rows = api_rows

    return rows


async def main() -> int:
    rows = await _fetch_all_rows()
    if not rows:
        print("No UK rows fetched", file=sys.stderr)
        return 1

    grouped = _group_rows(rows)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(
            {
                "listoumd": {
                    "rows": grouped,
                    "source_rows": len(rows),
                    "companies": len(grouped),
                }
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Saved {len(grouped)} UK companies ({len(rows)} source rows) to {OUTPUT}")
    if os.getenv("NV_OPENDATA_API_KEY"):
        print("Full dataset via NV_OPENDATA_API_KEY")
    elif len(rows) < 42:
        print(
            "Warning: partial dataset (public API limit). "
            "Set NV_OPENDATA_API_KEY for all 42 UK records.",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
