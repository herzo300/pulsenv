"""Fuel stations router — serves fuel prices and station list for the map."""
from __future__ import annotations

import json
import logging
from datetime import datetime, timezone, timedelta
from pathlib import Path

from fastapi import APIRouter, Query

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/fuel", tags=["fuel"])

# Resolve project root: routers/fuel.py → ../../..
ROOT = Path(__file__).resolve().parent.parent.parent.parent

# In-memory cache for both cities
_CACHE: dict = {}


def _load_fuel_data(city: str = "nizhnevartovsk") -> dict | None:
    """Load fuel stations JSON for the given city with simple caching."""
    filename = "fuel_stations_nsk.json" if city == "novosibirsk" else "fuel_stations_nv.json"
    file_path = ROOT / "public" / filename
    
    # Cache key format: "nsk" or "nv"
    cache_key = "nsk" if city == "novosibirsk" else "nv"
    
    try:
        mtime = file_path.stat().st_mtime
        cache_entry = _CACHE.get(cache_key)
        
        if cache_entry is None or cache_entry["mtime"] != mtime:
            data = json.loads(file_path.read_text(encoding="utf-8"))
            _CACHE[cache_key] = {"mtime": mtime, "data": data}
            
        return _CACHE[cache_key]["data"]
    except FileNotFoundError:
        logger.warning("Fuel file not found: %s", file_path)
        return None
    except Exception as e:
        logger.error("Failed to load fuel data for %s: %s", city, e)
        return None


@router.get("/prices")
def get_fuel_prices(city: str = Query("nizhnevartovsk")):
    """Return fuel stations with prices for the given city.

    Each station has: name, brand, lat, lng, address, prices (dict fuel→price),
    updated_at. Also returns city averages and minimums.
    """
    data = _load_fuel_data(city)
    if data is None:
        return {
            "success": False,
            "available": False,
            "error": "fuel data not loaded",
            "city": city,
        }

    return {
        "success": True,
        "available": True,
        "city": data.get("city", city),
        "city_name": "Нижневартовск",
        "generated_at": data.get("generated_at"),
        "source": data.get("source", "fuelprice.ru"),
        "total_stations": data.get("total_stations", 0),
        "stations": data.get("stations", []),
        "avg_prices": data.get("avg_prices", {}),
        "min_prices": data.get("min_prices", {}),
    }


@router.get("/best")
def get_best_prices(
    city: str = Query("nizhnevartovsk"),
    fuel: str = Query("АИ-95", description="Fuel type, e.g. АИ-95, АИ-92, ДТ"),
    limit: int = Query(5, ge=1, le=20),
):
    """Return top-N stations with cheapest price for a given fuel type."""
    data = _load_fuel_data(city)
    if data is None:
        return {"success": False, "available": False}

    stations = data.get("stations", [])
    matches = []
    for s in stations:
        prices = s.get("prices", {})
        # Try exact + normalized match
        price = prices.get(fuel)
        if price is None:
            # Try case-insensitive
            for k, v in prices.items():
                if k.lower() == fuel.lower():
                    price = v
                    break
        if price is not None:
            matches.append({
                "name": s.get("name"),
                "brand": s.get("brand"),
                "lat": s.get("lat"),
                "lng": s.get("lng"),
                "address": s.get("address"),
                "price": price,
                "updated_at": s.get("updated_at"),
            })
    matches.sort(key=lambda x: x["price"])
    return {
        "success": True,
        "available": True,
        "city": city,
        "fuel": fuel,
        "total": len(matches),
        "best": matches[:limit],
    }
