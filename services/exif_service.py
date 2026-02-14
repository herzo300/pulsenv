# services/exif_service.py
"""Извлечение GPS-координат из EXIF метаданных фотографий."""

import logging
from typing import Optional, Tuple
from PIL import Image
from PIL.ExifTags import TAGS, GPSTAGS

logger = logging.getLogger(__name__)


def _dms_to_decimal(dms, ref: str) -> float:
    """Конвертирует градусы/минуты/секунды в десятичные градусы."""
    degrees = float(dms[0])
    minutes = float(dms[1])
    seconds = float(dms[2])
    decimal = degrees + minutes / 60.0 + seconds / 3600.0
    if ref in ('S', 'W'):
        decimal = -decimal
    return decimal


def extract_gps_from_image(image_path: str) -> Optional[Tuple[float, float]]:
    """
    Извлекает GPS-координаты из EXIF метаданных фото.
    Возвращает (lat, lon) или None.
    """
    try:
        img = Image.open(image_path)
        exif_data = img._getexif()
        if not exif_data:
            return None

        gps_info = {}
        for tag_id, value in exif_data.items():
            tag_name = TAGS.get(tag_id, tag_id)
            if tag_name == 'GPSInfo':
                for gps_tag_id, gps_value in value.items():
                    gps_tag_name = GPSTAGS.get(gps_tag_id, gps_tag_id)
                    gps_info[gps_tag_name] = gps_value
                break

        if not gps_info:
            return None

        lat_dms = gps_info.get('GPSLatitude')
        lat_ref = gps_info.get('GPSLatitudeRef')
        lon_dms = gps_info.get('GPSLongitude')
        lon_ref = gps_info.get('GPSLongitudeRef')

        if not all([lat_dms, lat_ref, lon_dms, lon_ref]):
            return None

        lat = _dms_to_decimal(lat_dms, lat_ref)
        lon = _dms_to_decimal(lon_dms, lon_ref)

        # Базовая валидация
        if not (-90 <= lat <= 90 and -180 <= lon <= 180):
            return None

        logger.info(f"📍 EXIF GPS: {lat:.6f}, {lon:.6f}")
        return (lat, lon)

    except Exception as e:
        logger.debug(f"EXIF extract error: {e}")
        return None
