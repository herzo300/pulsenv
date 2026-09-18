#!/usr/bin/env python3
"""
Script to collect signal history for the past 30 days from public channels,
geoparse missing addresses/coordinates, and update the report database.
"""

import asyncio
import logging
from datetime import datetime, timedelta
import sys
import os

# Put root directory in Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.data_layer.database import SessionLocal
from services.data_layer.models import Report
from core.geoparse import _extract_address_from_text, nominatim_geocode

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

async def run_batch_geoparse():
    db = SessionLocal()
    try:
        # Fetch public source reports from the past 30 days
        since = datetime.utcnow() - timedelta(days=30)
        reports = (
            db.query(Report)
            .filter(Report.created_at >= since)
            .filter(
                (Report.source.like("vk:%"))
                | (Report.source.like("tg:%"))
                | (Report.source.like("telegram:%"))
            )
            .all()
        )
        
        logger.info(f"Loaded {len(reports)} public reports from the past month.")
        updated_count = 0

        for r in reports:
            text = f"{r.title or ''} {r.description or ''}"
            
            # Extract address if not set or invalid
            addr = r.address
            has_valid_address = addr and len(addr) > 5 and not addr.endswith("центр")
            
            if not has_valid_address:
                extracted = _extract_address_from_text(text)
                if extracted:
                    logger.info(f"Report {r.id}: Extracted address '{extracted}'")
                    r.address = extracted
                    addr = extracted
                    has_valid_address = True
            
            # Geocode coordinates if missing
            if has_valid_address and (r.lat is None or r.lng is None):
                try:
                    lat, lng = await nominatim_geocode(addr)
                    if lat and lng:
                        logger.info(f"Report {r.id}: Geocoded '{addr}' to ({lat}, {lng})")
                        r.lat = lat
                        r.lng = lng
                        updated_count += 1
                except Exception as ex:
                    logger.error(f"Geocoding error for '{addr}': {ex}")

        if updated_count > 0:
            db.commit()
            logger.info(f"Database updated successfully. Geocoded {updated_count} incidents.")
        else:
            logger.info("No reports needed update or geocoding.")

    except Exception as e:
        logger.error(f"Error during batch geoparse: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    logger.info("Starting batch incident collector...")
    asyncio.run(run_batch_geoparse())
    logger.info("Done.")
