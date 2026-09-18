# services/Backend/routers/geocoding.py
"""Reverse geocoding endpoint."""

import logging

from fastapi import APIRouter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["geocoding"])


@router.get("/geo/reverse")
async def reverse_geocode_from_backend(lat: float, lon: float):
    """Backend-first reverse geocoder used by the mobile client."""
    from services.geo_service import resolve_address_from_coords

    try:
        address = await resolve_address_from_coords(float(lat), float(lon))
    except Exception as exc:
        logger.warning("Reverse geocode failed for %s,%s: %s", lat, lon, exc)
        from services.geo_service import format_gps_fallback_address

        address = format_gps_fallback_address(float(lat), float(lon))
    return {"address": address, "lat": lat, "lon": lon}
