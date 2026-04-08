import argparse
import asyncio
import logging
import sys
from pathlib import Path
from typing import Iterable

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from backend.database import SessionLocal
from backend.models import Report
from services.geo_service import geoparse, sanitize_address_candidate

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("backfill_public_geocodes")
logging.getLogger("httpx").setLevel(logging.WARNING)


def _is_public_source(source: str) -> bool:
    value = (source or "").lower()
    return value.startswith(("vk:", "telegram:", "tg:", "public:", "camera_ai"))


def _load_candidates(limit: int) -> list[Report]:
    db = SessionLocal()
    try:
        reports = (
            db.query(Report)
            .filter(Report.lat.is_(None), Report.lng.is_(None))
            .order_by(Report.created_at.desc())
            .limit(limit * 3)
            .all()
        )
        return [report for report in reports if _is_public_source(report.source or "")][:limit]
    finally:
        db.close()


def _persist_geo(report_id: int, lat: float, lng: float, address: str | None) -> None:
    db = SessionLocal()
    try:
        report = db.query(Report).filter(Report.id == report_id).first()
        if not report:
            return
        report.lat = lat
        report.lng = lng
        if address:
            report.address = address
        db.commit()
    finally:
        db.close()


async def _process_reports(reports: Iterable[Report]) -> tuple[int, int]:
    checked = 0
    updated = 0
    for report in reports:
        checked += 1
        text = "\n".join(
            part for part in [report.title, report.description] if part
        )
        geo = await geoparse(
            text=text,
            ai_address=sanitize_address_candidate(report.address),
            location_hints=sanitize_address_candidate(report.address),
        )
        lat = geo.get("lat")
        lng = geo.get("lng")
        if lat is None or lng is None:
            logger.info("skip report=%s source=%s address=%s", report.id, report.source, report.address)
            continue
        await asyncio.to_thread(
            _persist_geo,
            report.id,
            float(lat),
            float(lng),
            geo.get("address") or report.address,
        )
        updated += 1
        logger.info(
            "updated report=%s source=%s address=%s geo_source=%s",
            report.id,
            report.source,
            geo.get("address") or report.address,
            geo.get("geo_source"),
        )
    return checked, updated


async def main() -> None:
    parser = argparse.ArgumentParser(description="Backfill coordinates for public reports.")
    parser.add_argument("--limit", type=int, default=200, help="Maximum reports to process")
    args = parser.parse_args()

    reports = _load_candidates(args.limit)
    checked, updated = await _process_reports(reports)
    logger.info("done checked=%s updated=%s", checked, updated)


if __name__ == "__main__":
    asyncio.run(main())
