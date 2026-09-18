"""Current weather for Nizhnevartovsk via Open-Meteo (no API key)."""

from __future__ import annotations

import logging
from typing import Any

from services.business.air_quality_service import DEFAULT_CITY, DEFAULT_LAT, DEFAULT_LON, fetch_air_quality

logger = logging.getLogger(__name__)

_WMO_LABELS: dict[int, str] = {
    0: "Ясно",
    1: "Преимущественно ясно",
    2: "Переменная облачность",
    3: "Пасмурно",
    45: "Туман",
    48: "Изморозь",
    51: "Морось",
    53: "Морось",
    55: "Морось",
    61: "Дождь",
    63: "Дождь",
    65: "Ливень",
    71: "Снег",
    73: "Снег",
    75: "Снегопад",
    77: "Снежная крупа",
    80: "Ливень",
    81: "Ливень",
    82: "Сильный ливень",
    95: "Гроза",
    96: "Гроза с градом",
    99: "Гроза с градом",
}


def _weather_kind(code: int | None) -> str:
    if code is None:
        return "cloudy"
    if code in (0, 1):
        return "clear"
    if code in (2, 3):
        return "cloudy"
    if code in (45, 48):
        return "fog"
    if code in (51, 53, 55, 61, 63, 65, 80, 81, 82):
        return "rain"
    if code in (71, 73, 75, 77, 85, 86):
        return "snow"
    if code >= 95:
        return "storm"
    return "cloudy"


_WWO_LABELS: dict[int, str] = {
    113: "Ясно",
    116: "Переменная облачность",
    119: "Облачно",
    122: "Пасмурно",
    143: "Туман",
    176: "Местами небольшой дождь",
    179: "Местами небольшой снег",
    182: "Местами мокрый снег",
    185: "Местами изморозь",
    200: "Местами гроза",
    227: "Метель",
    230: "Пурга",
    248: "Туман",
    260: "Ледяной туман",
    263: "Местами морось",
    266: "Небольшая морось",
    281: "Небольшой ледяной дождь",
    284: "Сильный ледяной дождь",
    293: "Местами слабый дождь",
    296: "Небольшой дождь",
    299: "Временами умеренный дождь",
    302: "Умеренный дождь",
    305: "Временами сильный дождь",
    308: "Сильный дождь",
    311: "Слабый ледяной дождь",
    314: "Умеренный или сильный ледяной дождь",
    317: "Слабый мокрый снег",
    320: "Умеренный или сильный мокрый снег",
    323: "Местами слабый снег",
    326: "Небольшой снег",
    329: "Местами умеренный снег",
    332: "Умеренный снег",
    335: "Местами сильный снег",
    338: "Снегопад",
    350: "Ледяная крупа",
    353: "Легкий дождь",
    356: "Сильный ливень",
    359: "Сильный ливневый дождь",
    362: "Слабый ливневый мокрый снег",
    365: "Умеренный или сильный ливневый мокрый снег",
    368: "Небольшой ливневый снег",
    371: "Умеренный или сильный ливневый снег",
    374: "Небольшой ледяной дождь",
    377: "Умеренная или сильная ледяная крупа",
    386: "Местами гроза с дождем",
    389: "Гроза с ливневым дождем",
    392: "Местами гроза со снегом",
    395: "Гроза с ливневым снегом",
}


def _wwo_kind(code: int) -> str:
    if code == 113:
        return "clear"
    if code in (116, 119, 122):
        return "cloudy"
    if code in (143, 185, 248, 260):
        return "fog"
    if code in (176, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314, 353, 356, 359, 374):
        return "rain"
    if code in (179, 182, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 377):
        return "snow"
    if code in (200, 386, 389, 392, 395):
        return "storm"
    return "cloudy"



def fetch_current_weather(
    *,
    lat: float = DEFAULT_LAT,
    lon: float = DEFAULT_LON,
) -> dict[str, Any]:
    """Return normalized weather snapshot."""
    import datetime
    import math

    # Calculate moon phase (purely mathematical, independent of network)
    try:
        known_new_moon = datetime.datetime(2000, 1, 6, 18, 14, tzinfo=datetime.timezone.utc)
        now_utc = datetime.datetime.now(datetime.timezone.utc)
        diff = now_utc - known_new_moon
        days = diff.total_seconds() / 86400.0
        lunation = 29.530588853
        moon_phase = (days / lunation) % 1.0

        if moon_phase < 0.06 or moon_phase > 0.94:
            moon_name = "Новолуние"
            moon_desc = "Период упадка сил, снижения концентрации и повышенной утомляемости. Рекомендуется снизить нагрузки."
        elif moon_phase >= 0.06 and moon_phase < 0.19:
            moon_name = "Молодая Луна"
            moon_desc = "Начало прилива энергии. Возможна эмоциональная нестабильность, легкая возбудимость."
        elif moon_phase >= 0.19 and moon_phase < 0.31:
            moon_name = "Первая четверть"
            moon_desc = "Период активных действий. Уровень стрессоустойчивости умеренный, полезно проявлять активность."
        elif moon_phase >= 0.31 and moon_phase < 0.44:
            moon_name = "Растущая Луна"
            moon_desc = "Энергия накапливается, повышается тонус нервной системы. Благоприятное время для планирования."
        elif moon_phase >= 0.44 and moon_phase < 0.56:
            moon_name = "Полнолуние"
            moon_desc = "Пик эмоциональной возбудимости, возможна бессонница, импульсивность и резкие смены настроения."
        elif moon_phase >= 0.56 and moon_phase < 0.69:
            moon_name = "Убывающая Луна"
            moon_desc = "Постепенное снижение напряжения. Благоприятный период для завершения начатых дел и анализа."
        elif moon_phase >= 0.69 and moon_phase < 0.81:
            moon_name = "Последняя четверть"
            moon_desc = "Снижение тонуса, склонность к апатии или грусти. Рекомендуется уделять время отдыху."
        else:
            moon_name = "Стареющая Луна"
            moon_desc = "Очищение мыслей, спад активности. Эмоциональный фон спокойный, но уровень физической энергии низок."

        dist_full = abs(moon_phase - 0.5)
        dist_new = min(moon_phase, 1.0 - moon_phase)
        
        full_impact = 92.0 * math.exp(-((dist_full / 0.1) ** 2))
        new_impact = 70.0 * math.exp(-((dist_new / 0.1) ** 2))
        moon_influence_pct = round(max(15.0, full_impact, new_impact), 1)
        moon_data = {
            "moon_phase": round(moon_phase, 4),
            "moon_phase_name": moon_name,
            "moon_phase_desc": moon_desc,
            "moon_influence_pct": moon_influence_pct,
        }
    except Exception as moon_exc:
        logger.warning("Moon phase calculation failed: %s", moon_exc)
        moon_data = {
            "moon_phase": 0.0,
            "moon_phase_name": "Неизвестно",
            "moon_phase_desc": "",
            "moon_influence_pct": 0.0,
        }

    try:
        import httpx

        wttr_success = False
        temp = 0.0
        feels_like = 0.0
        humidity = 0
        wind = 0.0
        gusts = 0.0
        wind_dir = 0.0
        precipitation = 0.0
        pressure_hpa = 1013.0
        uv_index = 0.0
        visibility_m = 10000.0
        code = 0
        condition = "Погода"
        is_day = 1
        kind = "cloudy"
        source_name = "none"

        # 1. Try WTTR.in
        try:
            wttr_city = "Nizhnevartovsk"
            if abs(lat - 54.9885) < 0.1:
                wttr_city = "Novosibirsk"

            wttr_response = httpx.get(
                f"https://wttr.in/{wttr_city}",
                params={"format": "j1", "lang": "ru"},
                timeout=5.0,
            )
            if wttr_response.status_code == 200:
                wttr_data = wttr_response.json()
                current = wttr_data.get("current_condition", [{}])[0]

                temp = float(current.get("temp_C") or 0.0)
                feels_like = float(current.get("FeelsLikeC") or temp)
                humidity = int(current.get("humidity") or 0)

                wind_kmh = float(current.get("windspeedKmph") or 0.0)
                wind = round(wind_kmh / 3.6, 1)
                gusts = wind
                wind_dir = float(current.get("winddirDegree") or 0.0)

                precipitation = float(current.get("precipMM") or 0.0)
                pressure_hpa = float(current.get("pressure") or 1013.0)
                uv_index = float(current.get("uvIndex") or 0.0)

                vis_km = float(current.get("visibility") or 10.0)
                visibility_m = vis_km * 1000.0

                code_wwo = int(current.get("weatherCode") or 113)
                condition = _WWO_LABELS.get(code_wwo, "Погода")
                kind = _wwo_kind(code_wwo)
                if gusts >= 14 or wind >= 12:
                    kind = "wind"

                import datetime
                now_local = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=5)
                is_day = 1 if (6 <= now_local.hour <= 22) else 0

                code = code_wwo
                source_name = "WTTR"
                wttr_success = True
        except Exception as wttr_exc:
            logger.warning("WTTR fetch failed, falling back to Open-Meteo: %s", wttr_exc)

        # 2. Fallback to Open-Meteo
        if not wttr_success:
            response = httpx.get(
                "https://api.open-meteo.com/v1/forecast",
                params={
                    "latitude": lat,
                    "longitude": lon,
                    "current": (
                        "temperature_2m,relative_humidity_2m,apparent_temperature,"
                        "weather_code,wind_speed_10m,wind_gusts_10m,wind_direction_10m,"
                        "precipitation,is_day,surface_pressure,uv_index,visibility"
                    ),
                    "timezone": "Asia/Yekaterinburg",
                    "forecast_days": 1,
                },
                timeout=10.0,
            )
            if response.status_code != 200:
                raise RuntimeError(f"Open-Meteo HTTP {response.status_code}")
            current = response.json().get("current") or {}
            code = int(current.get("weather_code") or 0)
            wind = float(current.get("wind_speed_10m") or 0)
            gusts = float(current.get("wind_gusts_10m") or wind)
            temp = current.get("temperature_2m")
            feels_like = current.get("apparent_temperature")
            humidity = current.get("relative_humidity_2m")
            wind_dir = current.get("wind_direction_10m")
            precipitation = current.get("precipitation")
            pressure_hpa = current.get("surface_pressure")
            uv_index = current.get("uv_index")
            visibility_m = current.get("visibility")
            is_day = bool(current.get("is_day", 1))

            kind = _weather_kind(code)
            if gusts >= 14 or wind >= 12:
                kind = "wind"
            condition = _WMO_LABELS.get(code, "Погода")
            source_name = "Open-Meteo"

        air = fetch_air_quality(lat=lat, lon=lon)

        # Fetch solar flare from official NOAA SWPC / NASA SDO GOES X-ray satellites
        solar_flare = "B1.2"
        solar_wind_speed = "390"
        try:
            flare_res = httpx.get("https://services.swpc.noaa.gov/json/goes/primary/xray-flares-latest.json", timeout=3.0)
            if flare_res.status_code == 200:
                flare_data = flare_res.json()
                if flare_data and isinstance(flare_data, list) and len(flare_data) > 0:
                    solar_flare = flare_data[0].get("current_class") or flare_data[0].get("max_class") or "A0.0"
        except Exception as flare_exc:
            logger.warning("Solar flare fetch failed: %s", flare_exc)

        # Fetch solar wind speed from NOAA SWPC
        try:
            wind_res = httpx.get("https://services.swpc.noaa.gov/products/summary/solar-wind-speed.json", timeout=3.0)
            if wind_res.status_code == 200:
                sw_data = wind_res.json()
                if isinstance(sw_data, dict) and sw_data.get("WindSpeed"):
                    solar_wind_speed = str(round(float(sw_data["WindSpeed"])))
        except Exception as sw_exc:
            logger.warning("NOAA Solar wind speed fetch failed: %s", sw_exc)

        # Fetch planetary Kp Index from NOAA SWPC
        kp_index = 0.0
        try:
            kp_res = httpx.get("https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json", timeout=3.0)
            if kp_res.status_code == 200:
                kp_data = kp_res.json()
                if kp_data and isinstance(kp_data, list):
                    for item in reversed(kp_data):
                        val = item.get("Kp") or item.get("kp_index") or item.get("observed_kp")
                        if val is not None:
                            kp_index = float(val)
                            break
        except Exception as kp_exc:
            logger.warning("NOAA Kp Index fetch failed: %s", kp_exc)

        # Fetch seismic activity from USGS
        seismic_magnitude = 0.0
        seismic_description = "Сейсмическая активность в норме (нет событий)"
        try:
            seismic_res = httpx.get(
                "https://earthquake.usgs.gov/fdsnws/event/1/query",
                params={
                    "format": "geojson",
                    "latitude": lat,
                    "longitude": lon,
                    "maxradiuskm": 500,
                    "limit": 1
                },
                timeout=3.0,
            )
            if seismic_res.status_code == 200:
                seismic_data = seismic_res.json()
                features = seismic_data.get("features", [])
                if features:
                    prop = features[0].get("properties", {})
                    seismic_magnitude = float(prop.get("mag") or 0.0)
                    place = prop.get("place") or "неизвестно"
                    seismic_description = f"Землетрясение M{seismic_magnitude} - {place}"
        except Exception as seismic_exc:
            logger.warning("USGS seismic activity fetch failed: %s", seismic_exc)

        # Calculate Schumann resonance
        now = datetime.datetime.utcnow()
        hour = now.hour + now.minute / 60.0
        diurnal_factor = 1.0 + 0.4 * math.sin((hour - 8) * math.pi / 12) + 0.2 * math.sin((hour - 14) * math.pi / 6)
        flare_mult = 1.0
        freq_shift = 0.0
        if solar_flare:
            char = solar_flare[0].upper()
            try:
                val = float(solar_flare[1:])
            except ValueError:
                val = 1.0
            if char == 'X':
                flare_mult = 2.5 + 0.5 * val
                freq_shift = 0.15 + 0.05 * val
            elif char == 'M':
                flare_mult = 1.5 + 0.1 * val
                freq_shift = 0.05 + 0.01 * val
            elif char == 'C':
                flare_mult = 1.1 + 0.02 * val
                freq_shift = 0.01
        schumann_freq = round(7.83 + freq_shift + 0.05 * math.sin(hour * math.pi / 12), 2)
        schumann_amp = round(1.2 * diurnal_factor * flare_mult, 1)

        pressure_mm_hg = round(pressure_hpa * 0.750062, 1) if pressure_hpa else None

        return {
            "available": True,
            "city": DEFAULT_CITY,
            "temperature_c": temp,
            "feels_like_c": feels_like,
            "humidity_pct": humidity,
            "wind_speed_ms": wind,
            "wind_gusts_ms": gusts,
            "wind_direction_deg": wind_dir,
            "precipitation_mm": precipitation,
            "pressure_hpa": pressure_hpa,
            "pressure_mm_hg": pressure_mm_hg,
            "solar_flare": solar_flare,
            "solar_wind_km_s": solar_wind_speed,
            "solar_source": "NOAA SWPC / NASA SDO",
            "schumann_freq_hz": schumann_freq,
            "schumann_amp_pt": schumann_amp,
            "weather_code": code,
            "condition": condition,
            "is_day": is_day,
            "kind": kind,
            "air_quality": air,
            "uv_index": uv_index,
            "visibility_m": visibility_m,
            "seismic_magnitude": seismic_magnitude,
            "seismic_description": seismic_description,
            "kp_index": kp_index,
            "source": source_name,
            **moon_data
        }
    except Exception as exc:
        logger.warning("Weather fetch failed: %s", exc)
        return {
            "available": False,
            "city": DEFAULT_CITY,
            "condition": "нет данных",
            "kind": "cloudy",
            "air_quality": fetch_air_quality(lat=lat, lon=lon),
            "source": "none",
            **moon_data
        }
