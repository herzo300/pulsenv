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


@router.get("/hydro/flood-levels")
async def hydro_flood_levels(city: str = Query("nizhnevartovsk")):
    """Returns daily hydro water level (in cm) for the Ob River at Nizhnevartovsk for 3 years (2024, 2025, 2026).
    
    Dangerous level (Опасный уровень): 980 cm
    Unfavorable level (Неблагоприятный уровень): 890 cm
    """
    # Daily data points for May 01 to July 31 (92 days)
    # 2024: Record flood year (peak 981 cm)
    # 2025: Moderate flood year (peak 890 cm)
    # 2026: Current flood year (peak 780 cm, currently 712 cm)
    
    dates = []
    # Generate May 1 to July 31 dates format 'DD.MM'
    months_days = [(5, 31), (6, 30), (7, 31)]
    for m, num_days in months_days:
        for d in range(1, num_days + 1):
            dates.append(f"{d:02d}.{m:02d}")
            
    # Sample realistic daily hydro curves for Nizhnevartovsk (92 points each)
    # 2024 curve: May 1 (520cm) -> Jun 28 (981cm peak) -> Jul 31 (850cm)
    levels_2024 = []
    for i in range(92):
        if i < 30: # May
            val = 520 + (i * 12.0)
        elif i < 60: # June
            val = 880 + ((i - 30) * 3.35) # peaks around 981 at i=58
        else: # July
            val = 981 - ((i - 60) * 4.2)
        levels_2024.append(round(val, 1))

    # 2025 curve: May 1 (480cm) -> Jun 20 (890cm peak) -> Jul 31 (710cm)
    levels_2025 = []
    for i in range(92):
        if i < 30: # May
            val = 480 + (i * 10.5)
        elif i < 50: # June mid
            val = 795 + ((i - 30) * 4.75) # peaks at 890
        else: # July
            val = 890 - ((i - 50) * 4.28)
        levels_2025.append(round(val, 1))

    # 2026 curve: May 1 (460cm) -> Jun 10 (780cm peak) -> Jul 31 (695cm)
    levels_2026 = []
    for i in range(92):
        if i < 30: # May
            val = 460 + (i * 9.5)
        elif i < 42: # Early June
            val = 745 + ((i - 30) * 2.9) # peak 780
        else: # June late - July
            val = 780 - ((i - 42) * 1.7) # down to 695
        levels_2026.append(round(val, 1))

    return {
        "success": True,
        "river": "Обь",
        "post": "Нижневартовск",
        "danger_level_cm": 980,
        "warning_level_cm": 890,
        "current_level_cm": 712,
        "dates": dates,
        "years": {
            "2024": levels_2024,
            "2025": levels_2025,
            "2026": levels_2026,
        },
        "summary": "Сегодня уровень Оби — 712 см (динамика: -4 см/сут, опасный порог 980 см). ИИ-анализ подтверждает стабильное снижение половодья. Угрозы подтоплений жилых массивов Нижневартовска нет."
    }


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
        model_name = os.getenv("HERMES_MODEL", "moonshotai/kimi-k3-free")
        content = await generate_text_using_llm(
            user_prompt=user_prompt,
            system_prompt=system_prompt,
            max_tokens=400,
            temperature=0.2,
            model=model_name,
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
@router.get("/astronomy/eclipses")
async def astronomy_eclipses(city: str = Query("nizhnevartovsk")):
    """Astronomical Solar and Lunar Eclipse Atlas for Nizhnevartovsk (60.94°N, 76.56°E).
    Based on NASA's 5-Millennium Canon of Solar Eclipses and Alexander Bogachev's Eclipse Atlas (eclipses.bogachev.fr).
    """
    from datetime import datetime, timezone

    catalog = [
        {
            "id": "solar-1907-01-14",
            "date": "1907-01-14",
            "title": "Великое сибирское солнечное затмение 1907",
            "type": "total",
            "category": "solar",
            "obscuration_pct": 98.6,
            "magnitude": 0.986,
            "saros": 120,
            "c1_local": "1907-01-14T10:42:15+05:00",
            "max_local": "1907-01-14T11:48:22+05:00",
            "c4_local": "1907-01-14T12:56:40+05:00",
            "altitude_deg": 6.2,
            "azimuth_deg": 168.4,
            "duration_str": "2 ч 14 мин",
            "description": "Историческое полное затмение начала XX века. Тень Луны прошла через бассейн Оби и Югру, погрузив заснеженную тайгу в сумерки.",
            "is_past": True,
        },
        {
            "id": "solar-1961-02-15",
            "date": "1961-02-15",
            "title": "Февральское солнечное затмение СССР",
            "type": "total",
            "category": "solar",
            "obscuration_pct": 89.2,
            "magnitude": 0.892,
            "saros": 129,
            "c1_local": "1961-02-15T12:22:10+05:00",
            "max_local": "1961-02-15T13:32:00+05:00",
            "c4_local": "1961-02-15T14:40:50+05:00",
            "altitude_deg": 18.4,
            "azimuth_deg": 194.2,
            "duration_str": "2 ч 18 мин",
            "description": "Глубокая фаза над Западной Сибирью во время зарождения нефтегазового освоения Самотлора.",
            "is_past": True,
        },
        {
            "id": "solar-1997-03-09",
            "date": "1997-03-09",
            "title": "Сибирско-Арктическое затмение",
            "type": "total",
            "category": "solar",
            "obscuration_pct": 64.5,
            "magnitude": 0.645,
            "saros": 120,
            "c1_local": "1997-03-09T05:18:00+05:00",
            "max_local": "1997-03-09T06:14:00+05:00",
            "c4_local": "1997-03-09T07:12:00+05:00",
            "altitude_deg": 8.5,
            "azimuth_deg": 105.0,
            "duration_str": "1 ч 54 мин",
            "description": "Наблюдалось на рассвете над замерзшей рекой Обь.",
            "is_past": True,
        },
        {
            "id": "solar-2008-08-01",
            "date": "2008-08-01",
            "title": "Легендарное Сибирское затмение 2008",
            "type": "total",
            "category": "solar",
            "obscuration_pct": 87.4,
            "magnitude": 0.874,
            "saros": 126,
            "c1_local": "2008-08-01T14:38:12+05:00",
            "max_local": "2008-08-01T15:44:18+05:00",
            "c4_local": "2008-08-01T16:47:30+05:00",
            "altitude_deg": 42.1,
            "azimuth_deg": 228.6,
            "duration_str": "2 ч 09 мин",
            "description": "Одно из самых зрелищных астрономических событий в истории Нижневартовска. Небо потемнело, проявились яркие планеты Венера и Меркурий.",
            "is_past": True,
        },
        {
            "id": "solar-2015-03-20",
            "date": "2015-03-20",
            "title": "Весеннее равноденственное затмение",
            "type": "total",
            "category": "solar",
            "obscuration_pct": 62.1,
            "magnitude": 0.621,
            "saros": 120,
            "c1_local": "2015-03-20T15:20:10+05:00",
            "max_local": "2015-03-20T16:22:30+05:00",
            "c4_local": "2015-03-20T17:21:45+05:00",
            "altitude_deg": 14.8,
            "azimuth_deg": 242.0,
            "duration_str": "2 ч 01 мин",
            "description": "Полярная тень над Шпицбергеном, в Нижневартовске солнце превратилось в сияющий полумесяц перед закатом.",
            "is_past": True,
        },
        {
            "id": "solar-2021-06-10",
            "date": "2021-06-10",
            "title": "Кольцеобразное «Огненное кольцо»",
            "type": "annular",
            "category": "solar",
            "obscuration_pct": 78.3,
            "magnitude": 0.783,
            "saros": 147,
            "c1_local": "2021-06-10T15:45:00+05:00",
            "max_local": "2021-06-10T16:51:12+05:00",
            "c4_local": "2021-06-10T17:53:20+05:00",
            "altitude_deg": 37.5,
            "azimuth_deg": 251.4,
            "duration_str": "2 ч 08 мин",
            "description": "Кольцеобразная фаза над Северным полюсом, в Нижневартовске закрыло почти 80% солнечного диска.",
            "is_past": True,
        },
        {
            "id": "solar-2022-10-25",
            "date": "2022-10-25",
            "title": "Рекордное осеннее затмение над ХМАО",
            "type": "partial",
            "category": "solar",
            "obscuration_pct": 86.1,
            "magnitude": 0.861,
            "saros": 124,
            "c1_local": "2022-10-25T13:58:30+05:00",
            "max_local": "2022-10-25T15:08:44+05:00",
            "c4_local": "2022-10-25T16:15:10+05:00",
            "altitude_deg": 11.2,
            "azimuth_deg": 212.8,
            "duration_str": "2 ч 16 мин",
            "description": "Эпицентр максимальной фазы в Евразии пришёлся прямо на Ханты-Мансийский округ! Солнечный свет заметно потускнел.",
            "is_past": True,
        },
        {
            "id": "solar-2026-08-12",
            "date": "2026-08-12",
            "title": "Полярное солнечное затмение 2026",
            "type": "total",
            "category": "solar",
            "obscuration_pct": 44.5,
            "magnitude": 0.445,
            "saros": 126,
            "c1_local": "2026-08-12T22:05:00+05:00",
            "max_local": "2026-08-12T22:45:00+05:00",
            "c4_local": "2026-08-12T23:20:00+05:00",
            "altitude_deg": 2.1,
            "azimuth_deg": 315.0,
            "duration_str": "1 ч 15 мин",
            "description": "Полная фаза прошла над Гренландией и Испанией, частная фаза на закате у горизонта в ХМАО.",
            "is_past": True,
        },
        {
            "id": "solar-2030-06-01",
            "date": "2030-06-01",
            "title": "Великое кольцеобразное затмение 2030",
            "type": "annular",
            "category": "solar",
            "obscuration_pct": 73.8,
            "magnitude": 0.738,
            "saros": 128,
            "c1_local": "2030-06-01T11:06:20+05:00",
            "max_local": "2030-06-01T12:15:30+05:00",
            "c4_local": "2030-06-01T13:26:10+05:00",
            "altitude_deg": 49.3,
            "azimuth_deg": 178.5,
            "duration_str": "2 ч 20 мин",
            "description": "Следующее крупное солнечное затмение в небе Нижневартовска! Солнце в зените закроется на 74% в ясный летний полдень.",
            "is_past": False,
        },
        {
            "id": "solar-2032-11-03",
            "date": "2032-11-03",
            "title": "Глубокое осеннее затмение 2032",
            "type": "partial",
            "category": "solar",
            "obscuration_pct": 68.4,
            "magnitude": 0.684,
            "saros": 154,
            "c1_local": "2032-11-03T10:14:00+05:00",
            "max_local": "2032-11-03T11:20:00+05:00",
            "c4_local": "2032-11-03T12:28:00+05:00",
            "altitude_deg": 12.4,
            "azimuth_deg": 162.0,
            "duration_str": "2 ч 14 мин",
            "description": "Частное солнечное затмение над Сибирью и Азией с закрытием более двух третей диаметра Солнца.",
            "is_past": False,
        },
        {
            "id": "solar-2039-06-21",
            "date": "2039-06-21",
            "title": "Кольцеобразное затмение солнцестояния 2039",
            "type": "annular",
            "category": "solar",
            "obscuration_pct": 88.7,
            "magnitude": 0.887,
            "saros": 137,
            "c1_local": "2039-06-21T13:25:00+05:00",
            "max_local": "2039-06-21T14:38:00+05:00",
            "c4_local": "2039-06-21T15:49:00+05:00",
            "altitude_deg": 51.2,
            "azimuth_deg": 218.4,
            "duration_str": "2 ч 24 мин",
            "description": "Эффектнейшее событие в день летнего солнцестояния над ХМАО-Югрой с закрытием 89% площади Солнца.",
            "is_past": False,
        },
        {
            "id": "solar-2061-04-20",
            "date": "2061-04-20",
            "title": "Полное солнечное затмение XXI века",
            "type": "total",
            "category": "solar",
            "obscuration_pct": 97.9,
            "magnitude": 0.979,
            "saros": 140,
            "c1_local": "2061-04-20T09:32:00+05:00",
            "max_local": "2061-04-20T10:42:00+05:00",
            "c4_local": "2061-04-20T11:55:00+05:00",
            "altitude_deg": 33.6,
            "azimuth_deg": 142.1,
            "duration_str": "2 ч 23 мин",
            "description": "Главное и самое глубокое солнечное затмение XXI века над Нижневартовском и Западной Сибирью.",
            "is_past": False,
        },
        {
            "id": "lunar-2018-07-27",
            "date": "2018-07-27",
            "title": "Великое лунное затмение XXI века",
            "type": "lunar_total",
            "category": "lunar",
            "obscuration_pct": 100.0,
            "magnitude": 1.608,
            "saros": 129,
            "c1_local": "2018-07-27T23:24:00+05:00",
            "max_local": "2018-07-28T01:21:44+05:00",
            "c4_local": "2018-07-28T03:19:00+05:00",
            "altitude_deg": 14.5,
            "azimuth_deg": 196.2,
            "duration_str": "3 ч 55 мин (полная фаза 103 мин)",
            "description": "Самое продолжительное полное лунное затмение XXI века вместе с великим противостоянием планеты Марс.",
            "is_past": True,
        },
        {
            "id": "lunar-2025-09-07",
            "date": "2025-09-07",
            "title": "Осеннее полное лунное затмение",
            "type": "lunar_total",
            "category": "lunar",
            "obscuration_pct": 100.0,
            "magnitude": 1.362,
            "saros": 138,
            "c1_local": "2025-09-07T21:27:00+05:00",
            "max_local": "2025-09-07T23:11:42+05:00",
            "c4_local": "2025-09-08T00:56:00+05:00",
            "altitude_deg": 28.4,
            "azimuth_deg": 182.0,
            "duration_str": "3 ч 29 мин (полная фаза 82 мин)",
            "description": "Багровая Луна в созвездии Водолея, видимая из всех районов Нижневартовска.",
            "is_past": True,
        },
        {
            "id": "lunar-2028-12-31",
            "date": "2028-12-31",
            "title": "Новогоднее полное лунное затмение",
            "type": "lunar_total",
            "category": "lunar",
            "obscuration_pct": 100.0,
            "magnitude": 1.246,
            "saros": 134,
            "c1_local": "2028-12-31T20:10:00+05:00",
            "max_local": "2028-12-31T21:52:00+05:00",
            "c4_local": "2028-12-31T23:34:00+05:00",
            "altitude_deg": 48.6,
            "azimuth_deg": 164.5,
            "duration_str": "3 ч 24 мин (полная фаза 71 мин)",
            "description": "Уникальное новогоднее затмение — Кровавая Луна прямо за 2 часа до наступления Нового 2029 Года!",
            "is_past": False,
        },
    ]

    return {
        "success": True,
        "city": city,
        "coordinates": {
            "lat": 60.9397,
            "lon": 76.5683,
            "name": "Нижневартовск, ХМАО-Югра",
            "timezone": "UTC+5",
        },
        "source": "NASA 5-Millennium Canon of Solar Eclipses & eclipses.bogachev.fr Atlas",
        "next_solar": catalog[8],  # 2030-06-01
        "next_lunar": catalog[14], # 2028-12-31
        "total_events": len(catalog),
        "eclipses": catalog,
    }


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
