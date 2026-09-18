#!/usr/bin/env python3
"""Принудительная пересадка ВСЕХ маркеров через Nominatim/OSM (прод)."""
import sys
sys.path.insert(0, "/app")
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from services.data_layer.database import SessionLocal
from services.data_layer.models import Report
from services.Backend.comprehensive_marker_geofix import (
    _CITY_PROFILES, _city_key, haversine_distance_m,
    load_knowledge_base, resolve_with_city,
)

def main():
    houses, inst, streets = load_knowledge_base()
    db = SessionLocal()
    fixed = same = 0
    try:
        reports = db.query(Report).all()
        print(f"Всего записей: {len(reports)}")
        for r in reports:
            addr = str(r.address or "")
            title = str(r.title or "")
            try:
                desc = str(r.to_dict().get("description") or "")
            except Exception:
                desc = ""
            city = _city_key(getattr(r, "city", None), addr)
            (lat, lng), src = resolve_with_city(addr, title, desc, city, houses, inst, streets)
            if r.lat is not None and r.lng is not None:
                d = haversine_distance_m(float(r.lat), float(r.lng), lat, lng)
            else:
                d = 99999.0
            if d <= 30.0:
                same += 1
                print(f"  #{r.id:<4} SAME {d:6.0f}м [{src}] {addr[:44]}")
                continue
            old = f"{r.lat},{r.lng}"
            r.lat, r.lng = lat, lng
            fixed += 1
            print(f"  #{r.id:<4} FIX {d:6.0f}м {old} -> {lat:.5f},{lng:.5f} [{src}] {addr[:34]}")
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
    print(f"\nГотово: исправлено {fixed}, уже точны {same}")

if __name__ == "__main__":
    main()
