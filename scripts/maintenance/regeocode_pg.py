#!/usr/bin/env python3
"""regeocode_pg.py — пересадка всех маркеров reports в PostgreSQL (прод)
строго по координатам: Nominatim/OSM -> локальная база (офлайн-фолбэк) ->
центр своего города. Запускать ВНУТРИ контейнера soobshio_backend:
    docker exec soobshio_backend python /app/services/Backend/scripts_tmp/regeocode_pg.py
"""
import sys

sys.path.insert(0, "/app")

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from services.data_layer.database import SessionLocal  # noqa: E402
from services.data_layer.models import Report  # noqa: E402
from services.Backend.comprehensive_marker_geofix import (  # noqa: E402
    _CITY_PROFILES,
    _city_key,
    haversine_distance_m,
    load_knowledge_base,
    resolve_with_city,
)


def main() -> None:
    houses, inst, streets = load_knowledge_base()
    db = SessionLocal()
    fixed, skipped = 0, 0
    try:
        reports = db.query(Report).all()
        print(f"Всего записей: {len(reports)}")
        for r in reports:
            addr = str(r.address or "")
            title = str(r.title or "")
            desc = ""
            try:
                desc = str(r.to_dict().get("description") or "")
            except Exception:
                pass
            city = _city_key(getattr(r, "city", None), addr)
            profile = _CITY_PROFILES.get(city, _CITY_PROFILES["nizhnevartovsk"])

            # Уже валидные координаты (внутри viewbox города, не чужой центр) — не трогаем
            if r.lat is not None and r.lng is not None:
                flat, flng = float(r.lat), float(r.lng)
                lon_min, lat_min, lon_max, lat_max = (
                    float(v) for v in profile["viewbox"].split(",")
                )
                in_vb = lat_min <= flat <= lat_max and lon_min <= flng <= lon_max
                foreign = any(
                    k != city
                    and haversine_distance_m(flat, flng, p["center"][0], p["center"][1]) < 50.0
                    for k, p in _CITY_PROFILES.items()
                )
                if in_vb and not foreign:
                    skipped += 1
                    print(f"  #{r.id:<4} OK  {city:14s} {flat:.5f},{flng:.5f}  {addr[:44]}")
                    continue

            (lat, lng), src = resolve_with_city(addr, title, desc, city, houses, inst, streets)
            old = f"{r.lat},{r.lng}"
            r.lat, r.lng = lat, lng
            fixed += 1
            print(f"  #{r.id:<4} FIX {city:14s} {old} -> {lat:.5f},{lng:.5f}  [{src}] {addr[:36]}")
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
    print(f"\nГотово: исправлено {fixed}, уже валидны {skipped}")


if __name__ == "__main__":
    main()
