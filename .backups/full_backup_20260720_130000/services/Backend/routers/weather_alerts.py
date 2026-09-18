"""Weather snapshot and city alert ticker."""

from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from services.business.city_alerts_service import get_cached_alerts, refresh_alerts
from services.business.weather_service import fetch_current_weather
from services.data_layer.database import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["weather-alerts"])


@router.get("/weather/current")
async def weather_current(city: str = Query("nizhnevartovsk")):
    # Возвращаем погоду из кэша, который обновляется раз в минуту
    return {"success": True, **get_cached_alerts(city=city).get("weather", {})}


@router.get("/alerts/ticker")
async def alerts_ticker(city: str = Query("nizhnevartovsk"), db: Session = Depends(get_db)):
    data = get_cached_alerts(city=city)
    if not data.get("updated_at"):
        data = refresh_alerts(db, city=city)
    return {"success": True, **data}


@router.get("/air-quality")
async def air_quality(city: str = Query("nizhnevartovsk")):
    """Real-time air quality snapshot for the city.

    Sources: Open-Meteo Air Quality (primary) → OpenAQ v3 (if OPENAQ_API_TOKEN) → WAQI.
    Returns: european_aqi, us_aqi, level, pm25, pm10, no2, o3, so2, co, source.
    Supported cities: nizhnevartovsk (default), novosibirsk.
    """
    from services.business.air_quality_service import fetch_air_quality

    aq = fetch_air_quality(city=city)
    return {"success": True, "city": city, **aq}


@router.post("/alerts/refresh")
async def alerts_refresh(db: Session = Depends(get_db)):
    data = refresh_alerts(db)
    return {"success": True, **data}


# Cache for eco advisories
_eco_cache = {}

@router.get("/weather/eco-health")
async def weather_eco_health(city: str = Query("nizhnevartovsk")):
    """Returns AI-generated Eco & Health advisory based on real-time PM2.5, UV, pressure and Kp index."""
    import time
    import json
    import re
    from services.business.air_quality_service import fetch_air_quality
    from services.ai.zai_service import generate_text_using_llm

    # 1. Fetch current metrics
    weather_data = get_cached_alerts(city=city).get("weather", {})
    aq_data = fetch_air_quality(city=city)

    temp = weather_data.get("temp", 15.0)
    pressure = weather_data.get("pressure", 760.0)
    wind_speed = weather_data.get("wind_speed", 3.0)
    kp = weather_data.get("kp_index", 2.0)
    uv = weather_data.get("uv", 1.0)
    pm25 = aq_data.get("pm2_5", 5.0)
    pm10 = aq_data.get("pm10", 12.0)
    aqi_level = aq_data.get("level", "Отличное")

    # 2. Check cache (cache TTL: 30 minutes)
    now = time.time()
    cache_key = f"{city}_{round(temp)}_{round(pm25)}_{round(kp)}"
    if cache_key in _eco_cache:
        cached_val, cached_time = _eco_cache[cache_key]
        if now - cached_time < 1800:
            return {"success": True, **cached_val}

    # 3. Ask Hermes/AI for personalized advice based on these real stats
    system_prompt = (
        "Ты — ИИ-эколог и медицинский консультант «Гермес».\n"
        "Тебе даны текущие показатели погоды и качества воздуха в городе.\n"
        "Твоя задача — сгенерировать 3 четкие, практичные рекомендации на русском языке:\n"
        "1. Для метеочувствительных людей (опирайся на давление и Kp-индекс геомагнитной активности).\n"
        "2. Для аллергиков и астматиков (опирайся на PM2.5, PM10 и уровень загрязнения).\n"
        "3. Для прогулок с детьми (опирайся на температуру, UV-индекс и скорость ветра).\n\n"
        "Каждая рекомендация должна быть краткой (1-2 предложения), емкой и содержать факты."
    )

    user_prompt = (
        f"Текущие показатели города:\n"
        f"- Температура: {temp}°C\n"
        f"- Атмосферное давление: {pressure} мм рт. ст.\n"
        f"- Качество воздуха (AQI): {aqi_level} (PM2.5: {pm25} мкг/м³, PM10: {pm10} мкг/м³)\n"
        f"- Геомагнитный Kp-индекс: {kp}\n"
        f"- УФ-индекс (UV): {uv}\n"
        f"- Скорость ветра: {wind_speed} м/с\n\n"
        f"Напиши рекомендации в формате JSON:\n"
        f"{{\n"
        f"  \"health\": \"совет метеочувствительным\",\n"
        f"  \"allergy\": \"совет аллергикам\",\n"
        f"  \"kids\": \"совет для прогулок с детьми\"\n"
        f"}}"
    )

    try:
        content = await generate_text_using_llm(
            user_prompt=user_prompt,
            system_prompt=system_prompt,
            max_tokens=400,
            temperature=0.2,
            model="nousresearch/hermes-3-llama-3.1-70b",
        )
        # Parse JSON
        adv = json.loads(re.search(r"\{.*\}", content, re.DOTALL).group(0))
    except Exception as e:
        logger.warning("Failed to generate AI eco advisory, using rules: %s", e)
        # Fallback to smart rule-based advice
        adv = {
            "health": "Геомагнитный фон спокойный. Самочувствие должно быть в норме." if kp < 4 else f"Магнитная буря {round(kp)} баллов. Возможны головные боли, избегайте физических нагрузок.",
            "allergy": "Качество воздуха отличное, риски для аллергиков отсутствуют." if pm25 < 15 else f"Повышено содержание пыли PM2.5 ({pm25} мкг/м³). Аллергикам рекомендуется надевать маску на улице.",
            "kids": f"Погода подходит для прогулок. Температура {temp}°C, УФ-индекс {uv}." if uv < 5 else f"Высокий УФ-индекс ({uv}). Нанесите солнцезащитный крем и избегайте прямых лучей с 12 до 16."
        }

    result = {
        "pm2_5": pm25,
        "pm10": pm10,
        "european_aqi": aq_data.get("european_aqi", 20),
        "kp_index": kp,
        "uv_index": uv,
        "pressure": pressure,
        "temp": temp,
        "level": aqi_level,
        "advisory": adv
    }

    _eco_cache[cache_key] = (result, now)
    return {"success": True, **result}


_sky_color_cache = {
    "hex": "#0D1B2A", # Default beautiful dark night sky color or neutral blue
    "timestamp": 0.0
}

@router.get("/weather/sky-color")
async def get_weather_sky_color():
    import time
    now = time.time()
    # Check cache (1 hour = 3600 seconds)
    if now - _sky_color_cache["timestamp"] < 3600:
        return {"success": True, "hex": _sky_color_cache["hex"], "cached": True}
    
    # Try capturing frame and calculating color
    try:
        from pathlib import Path
        import json
        import io
        from PIL import Image
        from services.Backend.routers.vlm import _capture_frame_from_url
        
        root = Path(__file__).resolve().parent.parent.parent.parent
        cameras_file = root / "public" / "cameras_nv.json"
        
        if not cameras_file.exists():
            return {"success": False, "error": "cameras_nv.json not found", "hex": _sky_color_cache["hex"]}
            
        with open(cameras_file, "r", encoding="utf-8") as f:
            cameras = json.load(f)
            
        online_cameras = [c for c in cameras if c.get("online") == True and (c.get("stream_url") or c.get("s"))]
        
        # Try to capture from the first few online cameras until one succeeds
        for cam in online_cameras[:5]:
            url = cam.get("stream_url") or cam.get("s")
            # Run blocking ffmpeg capture in a background thread to prevent blocking event loop
            img_bytes = await asyncio.to_thread(_capture_frame_from_url, url)
            if img_bytes:
                img = Image.open(io.BytesIO(img_bytes))
                width, height = img.size
                # Crop top 20% (sky region)
                sky_crop = img.crop((0, 0, width, int(height * 0.2)))
                # Resize to 1x1 to get average color
                sky_1x1 = sky_crop.resize((1, 1))
                r, g, b = sky_1x1.getpixel((0, 0))[:3]
                color_hex = f"#{r:02x}{g:02x}{b:02x}"
                
                # Update cache
                _sky_color_cache["hex"] = color_hex
                _sky_color_cache["timestamp"] = now
                return {"success": True, "hex": color_hex, "cached": False}
                
        # If all capture attempts fail, return last cached or default
        return {"success": True, "hex": _sky_color_cache["hex"], "cached": True, "warning": "All capture attempts failed"}
    except Exception as e:
        logger.warning("Error analyzing sky color: %s", e)
        return {"success": True, "hex": _sky_color_cache["hex"], "cached": True, "error": str(e)}


async def start_alerts_background_loop(app) -> None:
    """Poll weather + channel emergencies every 15 minutes."""

    async def _loop() -> None:
        await asyncio.sleep(8)
        while True:
            try:
                from services.data_layer.database import SessionLocal

                db = SessionLocal()
                try:
                    refresh_alerts(db, city="nizhnevartovsk")
                    refresh_alerts(db, city="novosibirsk")
                finally:
                    db.close()
                logger.info("City alerts ticker refreshed for all cities")
            except Exception as exc:
                logger.warning("Alerts refresh failed: %s", exc)
            await asyncio.sleep(60)

    task = asyncio.create_task(_loop())
    app.state.alerts_task = task
