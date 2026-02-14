#!/usr/bin/env python3
"""Тест: EXIF GPS + Vision анализ фото"""
import asyncio, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()

from services.exif_service import extract_gps_from_image
from PIL import Image
import piexif
import tempfile


def create_test_image_with_gps(lat: float, lon: float, path: str):
    """Создаёт тестовое JPEG с GPS EXIF."""
    img = Image.new('RGB', (100, 100), color='red')

    def decimal_to_dms(decimal):
        d = int(abs(decimal))
        m = int((abs(decimal) - d) * 60)
        s = round(((abs(decimal) - d) * 60 - m) * 60 * 10000)
        return ((d, 1), (m, 1), (s, 10000))

    lat_ref = 'N' if lat >= 0 else 'S'
    lon_ref = 'E' if lon >= 0 else 'W'

    gps_ifd = {
        piexif.GPSIFD.GPSLatitudeRef: lat_ref.encode(),
        piexif.GPSIFD.GPSLatitude: decimal_to_dms(lat),
        piexif.GPSIFD.GPSLongitudeRef: lon_ref.encode(),
        piexif.GPSIFD.GPSLongitude: decimal_to_dms(lon),
    }
    exif_dict = {"GPS": gps_ifd}
    exif_bytes = piexif.dump(exif_dict)
    img.save(path, "JPEG", exif=exif_bytes)


async def main():
    print("=" * 50)
    print("ТЕСТ EXIF GPS ИЗВЛЕЧЕНИЕ")
    print("=" * 50)

    # Тест 1: Фото с GPS (Нижневартовск, ул. Мира)
    tmp1 = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
    tmp1.close()
    test_lat, test_lon = 60.9380, 76.5968
    create_test_image_with_gps(test_lat, test_lon, tmp1.name)

    coords = extract_gps_from_image(tmp1.name)
    if coords:
        lat, lon = coords
        print(f"✅ EXIF GPS: {lat:.4f}, {lon:.4f} (ожидалось {test_lat}, {test_lon})")
        diff = abs(lat - test_lat) + abs(lon - test_lon)
        print(f"   Точность: отклонение {diff:.6f}°")
    else:
        print("❌ GPS не извлечён")

    os.unlink(tmp1.name)

    # Тест 2: Фото без GPS
    tmp2 = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
    tmp2.close()
    img = Image.new('RGB', (100, 100), color='blue')
    img.save(tmp2.name, "JPEG")

    coords2 = extract_gps_from_image(tmp2.name)
    if coords2 is None:
        print("✅ Фото без GPS → None (корректно)")
    else:
        print(f"❌ Фото без GPS вернуло: {coords2}")

    os.unlink(tmp2.name)

    # Тест 3: Vision анализ с EXIF
    print("\n" + "=" * 50)
    print("ТЕСТ VISION + EXIF")
    print("=" * 50)

    tmp3 = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
    tmp3.close()
    create_test_image_with_gps(60.9380, 76.5968, tmp3.name)

    from services.zai_vision_service import analyze_image_with_glm4v
    result = await analyze_image_with_glm4v(tmp3.name, "Машина на тротуаре, мешает пешеходам")
    print(f"   Провайдер: {result.get('provider')}")
    print(f"   Категория: {result.get('category')}")
    print(f"   Описание: {result.get('description', '')[:80]}")
    print(f"   Нарушение парковки: {result.get('has_vehicle_violation')}")
    print(f"   Номер авто: {result.get('plates')}")
    print(f"   EXIF lat: {result.get('exif_lat')}")
    print(f"   EXIF lon: {result.get('exif_lon')}")

    os.unlink(tmp3.name)
    print("\n✅ Все тесты завершены")


asyncio.run(main())
