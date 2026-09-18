"""Free camera frame analysis without paid vision APIs (OpenCV + heuristics)."""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any

from services.business.air_quality_service import (
    fetch_air_quality,
    format_air_quality_line,
)

logger = logging.getLogger(__name__)


def _opencv_available() -> bool:
    try:
        import cv2  # noqa: F401

        return True
    except ImportError:
        return False


def fetch_yandex_weather() -> dict[str, str]:
    """Scrapes Yandex.Pogoda for Nizhnevartovsk and returns parsed values."""
    url = "https://yandex.ru/pogoda/ru/nizhnevartovsk"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    results = {
        "temp": "Неизвестно",
        "condition": "Неизвестно",
        "wind": "Неизвестно",
        "humidity": "Неизвестно"
    }
    try:
        import httpx
        from bs4 import BeautifulSoup
        import re

        resp = httpx.get(url, headers=headers, timeout=5.0, follow_redirects=True)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, 'html.parser')
            temp_el = soup.select_one(".temp__value, [class*='FactTemperature_content'], .fact__temp")
            if temp_el:
                results["temp"] = temp_el.text.strip()
            
            cond_el = soup.select_one(".link__condition, [class*='Fact_warning__first_text'], .fact__condition, [class*='fact__condition']")
            if cond_el:
                results["condition"] = cond_el.text.strip()
            else:
                for tag in soup.find_all(class_=True):
                    classes = tag.get("class", [])
                    class_str = " ".join(classes).lower()
                    if 'condition' in class_str:
                        results["condition"] = tag.text.strip()
                        break
            
            all_text = soup.get_text(" ")
            wind_match = re.search(r'(\d+[\.,]\d+|\d+)\s*м/с', all_text)
            if wind_match:
                results["wind"] = wind_match.group(0)
                
            hum_match = re.search(r'(\d+)\s*%', all_text)
            if hum_match:
                results["humidity"] = hum_match.group(0)
    except Exception as e:
        logger.warning("Failed to fetch Yandex weather: %s", e)
    return results


def analyze_frame_bytes(image_bytes: bytes, *, camera_name: str = "Камера") -> dict[str, Any]:
    """Build a human-readable report from a JPEG/PNG frame."""
    if not image_bytes:
        return {
            "success": False,
            "report": "Не удалось получить кадр с камеры.",
            "metrics": {},
        }

    if not _opencv_available():
        return {
            "success": True,
            "report": (
                f"Камера «{camera_name}»: кадр получен ({len(image_bytes) // 1024} КБ). "
                "Детальный анализ недоступен на сервере без OpenCV."
            ),
            "metrics": {"frame_kb": len(image_bytes) // 1024},
            "provider": "frame_only",
        }

    import cv2
    import numpy as np

    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        return {
            "success": False,
            "report": "Кадр получен, но не удалось декодировать изображение.",
            "metrics": {},
        }

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape[:2]
    brightness = float(gray.mean())
    contrast = float(gray.std())
    sharpness = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    edges = cv2.Canny(gray, 80, 160)
    edge_ratio = float((edges > 0).mean())

    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    saturation = float(hsv[:, :, 1].mean())

    if brightness >= 120:
        time_hint = "день / хорошее освещение"
    elif brightness >= 55:
        time_hint = "сумерки или облачно"
    else:
        time_hint = "ночь или слабое освещение"

    if edge_ratio >= 0.14:
        activity = "высокая активность (много контуров — транспорт, люди, движение)"
    elif edge_ratio >= 0.07:
        activity = "умеренная активность"
    else:
        activity = "низкая активность, сцена спокойная"

    if sharpness < 40:
        quality = "кадр размытый или камера в тумане/дождь"
    elif sharpness < 120:
        quality = "кадр приемлемый"
    else:
        quality = "кадр чёткий"

    weather_hint = "погода на кадре не определяется точно"
    if saturation < 25 and brightness < 90:
        weather_hint = "возможны туман, снегопад или сильная пыль на объективе"
    elif saturation > 70 and brightness > 100:
        weather_hint = "ясные условия, хорошая видимость"

    yolo_summary = ""
    yolo_counts = None
    yolo_reason = "not_run"
    yolo_detections = 0
    try:
        from services.ai.yolo_edge_filter import analyze_frame, get_filter_status

        yolo = analyze_frame(image_bytes, camera_id=camera_name)
        yolo_reason = str(yolo.get("reason") or "ok")
        yolo_detections = int(yolo.get("detections_count") or 0)
        if yolo.get("summary"):
            yolo_summary = str(yolo["summary"]).strip()
        yolo_counts = yolo.get("counts")
        if yolo_reason == "model_unavailable":
            status = get_filter_status()
            missing = [
                key
                for key, meta in status.get("models", {}).items()
                if key == "coco" and not meta.get("exists")
            ]
            if missing:
                yolo_reason = "model_missing_on_server"
    except Exception as exc:
        yolo_reason = f"error:{exc.__class__.__name__}"
        logger.debug("YOLO free analysis skipped: %s", exc)

    weather = fetch_yandex_weather()
    air_quality = fetch_air_quality()

    lines = [
        f"📷 {camera_name}",
        f"🕒 {datetime.now(UTC).astimezone().strftime('%d.%m.%Y %H:%M')}",
        "",
        f"• Освещение: {time_hint} (яркость {brightness:.0f}/255)",
        f"• Активность: {activity}",
        f"• Качество кадра: {quality}",
        f"• Видимость: {weather_hint}",
        f"• Погода (Yandex): {weather['temp']}, {weather['condition']} (Ветер: {weather['wind']}, Влажность: {weather['humidity']})",
        format_air_quality_line(air_quality),
    ]
    yolo_used = bool(yolo_summary) or yolo_detections > 0
    if yolo_summary:
        lines.extend(["", "🤖 YOLO — детектор объектов:", yolo_summary])
        if yolo_counts:
            lines.extend([
                f"  • Люди: {yolo_counts.get('people', 0)}",
                f"  • Машины: {yolo_counts.get('vehicles', 0)}",
                f"  • Животные: {yolo_counts.get('animals', 0)}",
            ])
    elif yolo_reason == "model_unavailable":
        lines.extend(
            [
                "",
                "⚠️ YOLO недоступен: модель не загружена на сервере.",
            ]
        )
    elif yolo_reason == "model_missing_on_server":
        lines.extend(
            [
                "",
                "⚠️ YOLO недоступен: файл модели отсутствует в /app/models на VPS.",
            ]
        )
    elif yolo_reason == "edge_filter_disabled":
        lines.extend(["", "⚠️ YOLO отключён (EDGE_FILTER_ENABLED=false)."])
    elif yolo_used:
        lines.extend(["", "🤖 YOLO: объекты на кадре не обнаружены."])
    else:
        lines.extend(
            [
                "",
                "ℹ️ OpenCV-анализ выполнен. YOLO не дал результата.",
            ]
        )

    return {
        "success": True,
        "report": "\n".join(lines),
        "air_quality": air_quality,
        "yolo": {
            "used": yolo_used,
            "summary": yolo_summary,
            "counts": yolo_counts,
            "detections_count": yolo_detections,
            "reason": yolo_reason,
        },
        "metrics": {
            "width": w,
            "height": h,
            "brightness": round(brightness, 1),
            "contrast": round(contrast, 1),
            "sharpness": round(sharpness, 1),
            "edge_ratio": round(edge_ratio, 4),
            "saturation": round(saturation, 1),
        },
        "provider": "opencv_free",
    }
