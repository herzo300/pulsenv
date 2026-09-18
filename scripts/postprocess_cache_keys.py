"""
Post-process geocode_cache.json to add key variants that match
the backend's sanitize_address_candidate() normalization.

This ensures cache lookups succeed even when the backend transforms
addresses like 'бульвар' -> 'б-р' or 'проезд' -> 'проезд'.

Run this AFTER geocoding completes and BEFORE uploading to server.
"""
import json, sys, re
from pathlib import Path

sys.path.insert(0, ".")
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

from services.business.geo_service import sanitize_address_candidate, _normalize_key

cache_path = Path("data/geocode_cache.json")
cache = json.load(open(cache_path, encoding="utf-8"))
print(f"Starting cache: {len(cache)} entries")

# Load catalog to get all street/building combinations
catalog = json.load(open("data/uk_catalog.json", encoding="utf-8"))
rows = catalog.get("listoumd", {}).get("rows", [])

added = 0
missing = 0

for u in rows:
    for m in u.get("MKD", []):
        if not isinstance(m, dict):
            continue
        street = str(m.get("STREET") or "").strip()
        if not street:
            continue
        for b in m.get("BUILDINGS", []):
            building = str(b).strip()
            if not building:
                continue
            
            # Construct address the same way the endpoint does (uk_ratings.py:122-128)
            street_lower = street.lower().strip()
            has_prefix = any(
                street_lower.startswith(p)
                for p in ["улица ", "ул. ", "ул ", "проспект ", "пр. ", "пр-т ",
                           "бульвар ", "б-р ", "проезд ", "переулок ", "пер. ",
                           "мкр.", "мкр ", "микрорайон "]
            )
            prefix = "" if has_prefix else "ул. "
            raw_address = f"{prefix}{street} {building}, Нижневартовск"
            
            # The geocoding script stores with this key
            geocode_key = _normalize_key(raw_address)
            
            # The backend lookup uses sanitize_address_candidate first
            sanitized = sanitize_address_candidate(raw_address)
            if sanitized:
                lookup_key = _normalize_key(sanitized)
            else:
                lookup_key = geocode_key
            
            # If we have coords under the geocode key, also store under lookup key
            if geocode_key in cache:
                if lookup_key not in cache and lookup_key != geocode_key:
                    cache[lookup_key] = cache[geocode_key]
                    added += 1
            elif lookup_key in cache:
                # We have it under lookup key but not geocode key
                pass
            else:
                missing += 1

print(f"Added {added} alias keys for sanitized lookups")
print(f"Missing coordinates: {missing}")
print(f"Final cache: {len(cache)} entries")

cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Written to {cache_path}")
print(f"File size: {cache_path.stat().st_size:,} bytes")
