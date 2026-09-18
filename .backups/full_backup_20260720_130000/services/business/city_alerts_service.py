"""24/7 city alert ticker — weather warnings + channel emergencies."""

from __future__ import annotations

import logging
import re
from datetime import UTC, datetime, timedelta
from typing import Any

from services.business.weather_service import fetch_current_weather

logger = logging.getLogger(__name__)

LOCAL_CITY_UTC_OFFSET = timedelta(hours=5)
_alert_cache: dict[str, dict[str, Any]] = {}

_EMERGENCY_KEYWORDS = re.compile(
    r"(?i)(чp|чрезвыч|эваку|пожар|взрыв|обруш|авар|утеч|газ|"
    r"шторм|ураган|смерч|сильн\w*\s+ветер|ветер\s+\d+|"
    r"голол|налед|метел|буран|мороз|замороз|"
    r"перекрыт|затоп|прорыв|без\s+света|отключ)"
)

_CITY_ADDRESS_HINT = re.compile(
    r"(?i)(нижневартовск|новосибирск|ул\.|улиц|пр\.|просп|пер\.|бульвар|"
    r"микрорайон|мкр\.|ш\.|шоссе|набереж)"
)


def _local_day_bounds() -> tuple[datetime, datetime]:
    local_now = datetime.utcnow() + LOCAL_CITY_UTC_OFFSET
    local_start = local_now.replace(hour=0, minute=0, second=0, microsecond=0)
    start_utc = local_start - LOCAL_CITY_UTC_OFFSET
    return start_utc, start_utc + timedelta(days=1)


def _weather_alerts(weather: dict[str, Any], city: str = "nizhnevartovsk") -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    if not weather.get("available"):
        return items

    gusts = float(weather.get("wind_gusts_ms") or 0)
    wind = float(weather.get("wind_speed_ms") or 0)
    code = int(weather.get("weather_code") or 0)
    kind = weather.get("kind", "")

    city_display_name = "Новосибирске" if city == "novosibirsk" else "Нижневартовске"

    if gusts >= 17 or wind >= 14:
        items.append(
            {
                "type": "weather",
                "severity": "high",
                "text": (
                    f"⚠️ Сильный ветер в {city_display_name}: порывы до {gusts:.0f} м/с. "
                    "Будьте осторожны на улице и у зданий."
                ),
            }
        )
    elif gusts >= 12 or wind >= 10:
        items.append(
            {
                "type": "weather",
                "severity": "medium",
                "text": (
                    f"💨 Усиление ветра: {wind:.0f}–{gusts:.0f} м/с. "
                    "Возможны порывы на открытых участках."
                ),
            }
        )

    if code in (65, 82, 95, 96, 99):
        items.append(
            {
                "type": "weather",
                "severity": "high",
                "text": f"🌧 {weather.get('condition', 'Непогода')}: "
                f"{weather.get('temperature_c', '—')}°C. Следите за обстановкой.",
            }
        )
    elif kind in ("storm", "snow") and code >= 71:
        items.append(
            {
                "type": "weather",
                "severity": "medium",
                "text": f"❄️ {weather.get('condition', 'Снег')}: "
                f"осторожно на дорогах и тротуарах.",
            }
        )

    # 1. Атмосферное давление
    pressure = weather.get("pressure_mm_hg")
    if pressure is not None:
        if pressure < 748:
            items.append({
                "type": "weather",
                "severity": "medium",
                "text": f"⚠️ Атмосферное давление понижено ({pressure:.1f} мм рт. ст., норма 748–768). Рекомендуется щадящий режим."
            })
        elif pressure > 768:
            items.append({
                "type": "weather",
                "severity": "medium",
                "text": f"⚠️ Атмосферное давление повышено ({pressure:.1f} мм рт. ст., норма 748–768). Возможна повышенная нагрузка на сосуды."
            })

    # 2. Солнечные вспышки
    flare = weather.get("solar_flare")
    if flare and isinstance(flare, str) and (flare.startswith("M") or flare.startswith("X")):
        severity = "high" if flare.startswith("X") else "medium"
        if flare.startswith("X"):
            text = f"💥 Зафиксирована критическая вспышка на Солнце (класс {flare}). Риск геомагнитных бурь. Метеозависимым людям и лицам с сердечно-сосудистыми заболеваниями рекомендуется контролировать давление и избегать переутомления."
        else:
            text = f"💥 Зафиксирована умеренная вспышка на Солнце (класс {flare}). Возможны колебания геомагнитного поля и умеренное недомогание у метеочувствительных людей."
        items.append({
            "type": "weather",
            "severity": severity,
            "text": text
        })

    # 3. Резонанс Шумана
    schumann_freq = weather.get("schumann_freq_hz")
    schumann_amp = weather.get("schumann_amp_pt")
    if schumann_freq is not None and (schumann_freq < 7.7 or schumann_freq > 8.0):
        items.append({
            "type": "weather",
            "severity": "medium",
            "text": f"🌀 Колебания резонанса Шумана: {schumann_freq:.2f} Гц (норма 7.83 Гц). Возможны нарушения сна."
        })
    if schumann_amp is not None and schumann_amp > 15.0:
        items.append({
            "type": "weather",
            "severity": "medium",
            "text": f"⚡ Всплеск амплитуды Шумана ({schumann_amp:.1f} pT, норма <=15). Возможно повышение утомляемости."
        })

    # 4. Геомагнитная активность (Kp)
    kp = weather.get("kp_index")
    if kp is not None:
        if kp >= 5.0:
            items.append({
                "type": "weather",
                "severity": "high",
                "text": f"🚨 Геомагнитная буря! Kp-индекс равен {kp:.1f} (буря >= 5). Ограничьте физические нагрузки."
            })
        elif kp >= 4.0:
            items.append({
                "type": "weather",
                "severity": "medium",
                "text": f"⚠️ Геомагнитное возмущение: Kp-индекс равен {kp:.1f}. Чувствительные люди могут испытывать недомогание."
            })

    # 5. Сейсмическая активность
    seismic_mag = weather.get("seismic_magnitude")
    seismic_desc = weather.get("seismic_description")
    if seismic_mag is not None and seismic_mag > 0.0:
        items.append({
            "type": "weather",
            "severity": "medium" if seismic_mag < 4.0 else "high",
            "text": f"🌋 Зафиксирована сейсмоактивность: {seismic_desc}."
        })

    aq = weather.get("air_quality") or {}
    if aq.get("available"):
        eu = aq.get("european_aqi")
        if eu is not None and float(eu) >= 80:
            items.append(
                {
                    "type": "air",
                    "severity": "medium",
                    "text": f"😷 Качество воздуха: {aq.get('level', 'плохое')} "
                    f"(EU AQI {eu}). Ограничьте активность на улице.",
                }
            )

    return items


def _channel_alerts(db) -> list[dict[str, Any]]:
    return []


def refresh_alerts(db=None, city: str = "nizhnevartovsk") -> dict[str, Any]:
    """Refresh cached ticker items (weather + channels) for the selected city."""
    lat = 54.9885 if city == "novosibirsk" else 60.9344
    lon = 82.9207 if city == "novosibirsk" else 76.5531
    weather = fetch_current_weather(lat=lat, lon=lon)
    items = _weather_alerts(weather, city=city)
    if db is not None:
        items.extend(_channel_alerts(db))

    weather_items = [i for i in items if i["type"] in ("weather", "air")]
    city_items = [i for i in items if i["type"] == "channel"]

    city_display_name = "Новосибирске" if city == "novosibirsk" else "Нижневартовске"

    if not weather_items:
        weather_items.append({
            "type": "weather_info",
            "severity": "low",
            "text": f"☀️ Погода в {city_display_name} в норме. Опасных погодных явлений не прогнозируется.",
        })
    if not city_items:
        city_items.append({
            "type": "city_info",
            "severity": "low",
            "text": f"✅ Обстановка в городе стабильная. Мониторинг городских сигналов и происшествий активен.",
        })

    weather_marquee = "   •   ".join(i["text"] for i in weather_items)
    city_marquee = "   •   ".join(i["text"] for i in city_items)

    payload = {
        "items": items,
        "weather": weather,
        "updated_at": datetime.now(UTC).isoformat(),
        "marquee": "   •   ".join(i["text"] for i in items) if items else f"✅ Критичных оповещений нет. Мониторинг погоды в {city_display_name} активен 24/7.",
        "weather_marquee": weather_marquee,
        "city_marquee": city_marquee,
    }
    _alert_cache[city] = payload
    return payload


def get_cached_alerts(city: str = "nizhnevartovsk") -> dict[str, Any]:
    if city not in _alert_cache or not _alert_cache[city].get("items"):
        return refresh_alerts(city=city)
    return dict(_alert_cache[city])
