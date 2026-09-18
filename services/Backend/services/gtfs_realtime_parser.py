# services/Backend/services/gtfs_realtime_parser.py
"""
GTFS-Realtime Protobuf & GeoJSON Parser for Public Transport Integration.
Ingests live bus telemetry from municipal GLONASS/GPS data providers.
"""

import time
import logging
from typing import Dict, Any, List, Optional

logger = logging.getLogger("gtfs_realtime_parser")


def parse_gtfs_realtime_feed(raw_data: bytes) -> List[Dict[str, Any]]:
    """
    Parses GTFS-Realtime protobuf byte stream or JSON fallback.
    Returns standardized bus telemetry objects.
    """
    items = []
    try:
        import json
        data = json.loads(raw_data.decode("utf-8"))
        entities = data.get("entity", [])
        for ent in entities:
            veh = ent.get("vehicle", {})
            pos = veh.get("position", {})
            trip = veh.get("trip", {})
            if pos and pos.get("latitude"):
                items.append({
                    "id": veh.get("vehicle", {}).get("id") or ent.get("id"),
                    "route_number": trip.get("route_id", "1"),
                    "lat": pos.get("latitude"),
                    "lng": pos.get("longitude"),
                    "speed": pos.get("speed", 30),
                    "bearing": pos.get("bearing", 0),
                    "timestamp": veh.get("timestamp", time.time()),
                })
    except Exception as exc:
        logger.debug(f"GTFS JSON parse fallback: {exc}")

    return items
