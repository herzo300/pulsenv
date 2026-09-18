"""Air quality for Nizhnevartovsk — Open-Meteo (primary) + WAQI (fallback)."""

from __future__ import annotations

import logging
import os
from typing import Any

logger = logging.getLogger(__name__)

# Центр карты «Пульс города»
DEFAULT_LAT = 60.9344
DEFAULT_LON = 76.5531
DEFAULT_CITY = "Нижневартовск"


def _european_aqi_label(value: float | int | None) -> str:
    if value is None:
        return "нет данных"
    v = float(value)
    if v <= 20:
        return "отличное"
    if v <= 40:
        return "хорошее"
    if v <= 60:
        return "умеренное"
    if v <= 80:
        return "плохое"
    if v <= 100:
        return "очень плохое"
    return "опасное"


def _us_aqi_label(value: float | int | None) -> str:
    if value is None:
        return "нет данных"
    v = float(value)
    if v <= 50:
        return "хорошо"
    if v <= 100:
        return "умеренно"
    if v <= 150:
        return "нездорово для чувствительных"
    if v <= 200:
        return "нездорово"
    if v <= 300:
        return "очень нездорово"
    return "опасно"


def _pollutant_name(code: str | None) -> str:
    mapping = {
        "pm25": "PM2.5",
        "pm10": "PM10",
        "no2": "NO₂",
        "o3": "O₃",
        "so2": "SO₂",
        "co": "CO",
    }
    if not code:
        return "—"
    return mapping.get(code.lower(), code.upper())


def _fetch_open_meteo_aq(
    lat: float = DEFAULT_LAT,
    lon: float = DEFAULT_LON,
) -> dict[str, Any] | None:
    try:
        import httpx

        response = httpx.get(
            "https://air-quality-api.open-meteo.com/v1/air-quality",
            params={
                "latitude": lat,
                "longitude": lon,
                "current": (
                    "european_aqi,us_aqi,pm2_5,pm10,"
                    "nitrogen_dioxide,ozone,sulphur_dioxide,carbon_monoxide"
                ),
                "timezone": "Asia/Yekaterinburg",
            },
            timeout=8.0,
        )
        if response.status_code != 200:
            return None
        current = response.json().get("current") or {}
        european = current.get("european_aqi")
        us_aqi = current.get("us_aqi")
        return {
            "european_aqi": european,
            "us_aqi": us_aqi,
            "level": _european_aqi_label(european),
            "us_level": _us_aqi_label(us_aqi),
            "pm25": current.get("pm2_5"),
            "pm10": current.get("pm10"),
            "no2": current.get("nitrogen_dioxide"),
            "o3": current.get("ozone"),
            "so2": current.get("sulphur_dioxide"),
            "co": current.get("carbon_monoxide"),
            "observed_at": current.get("time"),
            "source": "Open-Meteo",
            "city": DEFAULT_CITY,
        }
    except Exception as exc:
        logger.debug("Open-Meteo AQ failed: %s", exc)
        return None


def _fetch_waqi_aq(
    lat: float = DEFAULT_LAT,
    lon: float = DEFAULT_LON,
) -> dict[str, Any] | None:
    token = (os.getenv("WAQI_API_TOKEN") or "demo").strip()
    if not token:
        return None
    try:
        import httpx

        response = httpx.get(
            f"https://api.waqi.info/feed/geo:{lat};{lon}/",
            params={"token": token},
            timeout=8.0,
        )
        if response.status_code != 200:
            return None
        payload = response.json()
        if payload.get("status") != "ok":
            return None
        data = payload.get("data") or {}
        iaqi = data.get("iaqi") or {}
        aqi = data.get("aqi")
        return {
            "european_aqi": None,
            "us_aqi": aqi,
            "level": _us_aqi_label(aqi),
            "us_level": _us_aqi_label(aqi),
            "pm25": (iaqi.get("pm25") or {}).get("v"),
            "pm10": (iaqi.get("pm10") or {}).get("v"),
            "no2": (iaqi.get("no2") or {}).get("v"),
            "o3": (iaqi.get("o3") or {}).get("v"),
            "so2": (iaqi.get("so2") or {}).get("v"),
            "co": (iaqi.get("co") or {}).get("v"),
            "dominant_pollutant": data.get("dominentpol"),
            "station": (data.get("city") or {}).get("name"),
            "observed_at": data.get("time", {}).get("s"),
            "source": "WAQI",
            "city": DEFAULT_CITY,
        }
    except Exception as exc:
        logger.debug("WAQI AQ failed: %s", exc)
        return None


def _fetch_openaq_v3(
    lat: float = DEFAULT_LAT,
    lon: float = DEFAULT_LON,
) -> dict[str, Any] | None:
    """OpenAQ v3 — requires API key (OPENAQ_API_TOKEN env). Optional 3rd source."""
    token = (os.getenv("OPENAQ_API_TOKEN") or "").strip()
    if not token:
        return None
    try:
        import httpx

        response = httpx.get(
            "https://api.openaq.org/v3/latest",
            params={
                "coordinates": f"{lat},{lon}",
                "radius": 25000,
                "limit": 1,
            },
            headers={"X-API-Key": token, "Accept": "application/json"},
            timeout=8.0,
        )
        if response.status_code != 200:
            return None
        payload = response.json()
        results = payload.get("results") or []
        if not results:
            return None
        first = results[0]
        # OpenAQ v3 returns list of measurements
        measurements = {}
        for m in first.get("measurements") or []:
            param = (m.get("parameter") or "").lower()
            if param in ("pm25", "pm2.5"):
                measurements["pm25"] = m.get("value")
            elif param in ("pm10", "no2", "o3", "so2", "co"):
                measurements[param] = m.get("value")
        pm25 = measurements.get("pm25")
        us = _estimate_us_aqi_from_pm25(pm25) if pm25 is not None else None
        return {
            "european_aqi": None,
            "us_aqi": us,
            "level": _us_aqi_label(us),
            "us_level": _us_aqi_label(us),
            "pm25": pm25,
            "pm10": measurements.get("pm10"),
            "no2": measurements.get("no2"),
            "o3": measurements.get("o3"),
            "so2": measurements.get("so2"),
            "co": measurements.get("co"),
            "station": (first.get("location") or {}).get("name") or "OpenAQ",
            "observed_at": first.get("datetime", {}).get("utc"),
            "source": "OpenAQ",
        }
    except Exception as exc:
        logger.debug("OpenAQ v3 failed: %s", exc)
        return None


def _estimate_us_aqi_from_pm25(pm25: float) -> int:
    """Approximate US AQI from PM2.5 (EPA breakpoint table)."""
    try:
        v = float(pm25)
    except (TypeError, ValueError):
        return 0
    if v <= 12.0:
        return int(round(v / 12.0 * 50))
    if v <= 35.4:
        return int(round(51 + (v - 12.1) / 23.3 * 49))
    if v <= 55.4:
        return int(round(101 + (v - 35.5) / 19.9 * 49))
    if v <= 150.4:
        return int(round(151 + (v - 55.5) / 94.9 * 49))
    if v <= 250.4:
        return int(round(201 + (v - 150.5) / 99.9 * 99))
    if v <= 350.4:
        return int(round(301 + (v - 250.5) / 99.9 * 99))
    if v <= 500.4:
        return int(round(401 + (v - 350.5) / 149.9 * 99))
    return 501


# City coordinates registry (for /api/air-quality?city=...)
CITY_COORDS = {
    "nizhnevartovsk": (DEFAULT_LAT, DEFAULT_LON, "Нижневартовск"),
    "novosibirsk": (54.9885, 82.9207, "Новосибирск"),
}


def fetch_air_quality(
    *,
    lat: float = DEFAULT_LAT,
    lon: float = DEFAULT_LON,
    city: str | None = None,
) -> dict[str, Any]:
    """Return normalized air quality snapshot for the city.

    Tries Open-Meteo → OpenAQ v3 (optional, if OPENAQ_API_TOKEN set) → WAQI.
    """
    # Resolve city name from registry
    city_name = DEFAULT_CITY
    if city and city.lower() in CITY_COORDS:
        lat, lon, city_name = CITY_COORDS[city.lower()]

    result = _fetch_open_meteo_aq(lat=lat, lon=lon)
    if result is None:
        result = _fetch_openaq_v3(lat=lat, lon=lon)
    if result is None:
        result = _fetch_waqi_aq(lat=lat, lon=lon)
    if result is None:
        return {
            "available": False,
            "level": "нет данных",
            "summary": "Данные о качестве воздуха временно недоступны.",
            "source": "none",
            "city": city_name,
            "lat": lat,
            "lon": lon,
        }
    result["city"] = city_name
    result["lat"] = lat
    result["lon"] = lon

    parts: list[str] = []
    if result.get("european_aqi") is not None:
        parts.append(f"EU AQI {result['european_aqi']} ({result['level']})")
    if result.get("us_aqi") is not None:
        parts.append(f"US AQI {result['us_aqi']}")
    if result.get("pm25") is not None:
        parts.append(f"PM2.5 {result['pm25']:.1f} µg/m³")
    if result.get("pm10") is not None:
        parts.append(f"PM10 {result['pm10']:.1f} µg/m³")
    dominant = result.get("dominant_pollutant")
    if dominant:
        parts.append(f"основной: {_pollutant_name(str(dominant))}")

    result["available"] = True
    result["summary"] = ", ".join(parts) if parts else result.get("level", "нет данных")
    return result


def format_air_quality_line(aq: dict[str, Any]) -> str:
    """Single report line for camera analysis."""
    if not aq.get("available"):
        return "• Качество воздуха: данные недоступны"
    level = aq.get("level", "нет данных")
    source = aq.get("source", "—")
    eu = aq.get("european_aqi")
    pm25 = aq.get("pm25")
    chunks = [f"• Качество воздуха ({source}): {level}"]
    if eu is not None:
        chunks[0] += f", EU AQI {eu}"
    if pm25 is not None:
        chunks[0] += f", PM2.5 {pm25:.1f} µg/m³"
    return chunks[0]
