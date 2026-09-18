# scripts/geocode_fix_encoding.py
"""Re-geocode all houses with proper UTF-8 encoding to fix the cache."""
import asyncio
import json
import os
import sys
import re
from pathlib import Path
import httpx
from urllib.parse import quote

# Force UTF-8 output
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def clean_address(street, building):
    street = street.strip()
    building = building.strip()
    street_lower = street.lower()
    has_prefix = any(
        street_lower.startswith(p)
        for p in ["улица ", "ул. ", "ул ", "проспект ", "пр. ", "пр-т ", "бульвар ", "б-р ", "проезд ", "переулок ", "пер. ", "мкр.", "мкр ", "микрорайон "]
    )
    prefix = "" if has_prefix else "ул. "
    return f"{prefix}{street} {building}, Нижневартовск"

def normalize_key(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())

async def geocode_nominatim(client, street, building):
    full_address = clean_address(street, building)
    q = quote(full_address)
    url = f"https://nominatim.openstreetmap.org/search?q={q}&format=jsonv2&limit=5&countrycodes=ru"
    try:
        r = await client.get(url)
        if r.status_code == 429:
            return full_address, None, True
        if r.status_code != 200:
            return full_address, None, False
        data = r.json()
        if not data or not isinstance(data, list):
            return full_address, None, False
        for item in data:
            lat = item.get("lat")
            lon = item.get("lon")
            if lat and lon:
                display_name = item.get("display_name", "").lower()
                if "нижневартовск" in display_name or "nizhnevartovsk" in display_name:
                    return full_address, (float(lat), float(lon)), False
        first = data[0]
        lat = first.get("lat")
        lon = first.get("lon")
        if lat and lon:
            return full_address, (float(lat), float(lon)), False
    except Exception as e:
        print(f"  Error: {e}")
    return full_address, None, False

async def main():
    print("=== Geocoding with proper UTF-8 encoding ===")
    
    catalog_path = Path("data/uk_catalog.json")
    if not catalog_path.exists():
        print("Error: data/uk_catalog.json not found!")
        return
    
    with open(catalog_path, encoding="utf-8") as f:
        catalog_data = json.load(f)
    
    rows = catalog_data.get("listoumd", {}).get("rows", []) if isinstance(catalog_data, dict) else catalog_data
    
    # Start fresh cache - only keep valid UTF-8 entries
    cache_path = Path("data/geocode_cache.json")
    cache = {}
    if cache_path.exists():
        try:
            raw = json.loads(cache_path.read_text(encoding="utf-8"))
            # Keep only entries with valid Cyrillic keys (no replacement chars or garbled text)
            for k, v in raw.items():
                # Check if key has actual Cyrillic characters and no replacement chars
                if "\uFFFD" not in k and any('\u0400' <= c <= '\u04FF' for c in k):
                    cache[k] = v
            print(f"Loaded {len(cache)} valid cached entries")
        except Exception:
            print("Starting fresh cache")
    
    # Extract unique items
    unique_items = []
    seen = set()
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
                addr_key = normalize_key(clean_address(street, building))
                if addr_key not in seen:
                    seen.add(addr_key)
                    unique_items.append((street, building))
    
    print(f"Total unique houses: {len(unique_items)}")
    
    # Filter already cached
    to_geocode = [(s, b) for s, b in unique_items if normalize_key(clean_address(s, b)) not in cache]
    print(f"Already cached: {len(unique_items) - len(to_geocode)}. To geocode: {len(to_geocode)}")
    
    if not to_geocode:
        print("All done!")
        # Still write to ensure proper encoding
        cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
        return
    
    headers = {"User-Agent": "PulsGorodaGeocoding/4.0 (contact@soobshio.ru)"}
    success = 0
    fail = 0
    
    async with httpx.AsyncClient(timeout=8.0, headers=headers) as client:
        for idx, (s, b) in enumerate(to_geocode):
            addr = clean_address(s, b)
            norm = normalize_key(addr)
            print(f"[{idx+1}/{len(to_geocode)}] {addr}...", end="", flush=True)
            
            _, coords, rate_limited = await geocode_nominatim(client, s, b)
            if rate_limited:
                print(" Rate limited, waiting 10s...")
                await asyncio.sleep(10.0)
                _, coords, _ = await geocode_nominatim(client, s, b)
            
            if coords:
                cache[norm] = list(coords)
                success += 1
                print(f" OK: {coords}")
            else:
                fail += 1
                print(" FAIL")
            
            if (success + fail) % 10 == 0:
                cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
            
            await asyncio.sleep(1.3)
    
    cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nDone! Success: {success}, Failed: {fail}")
    print(f"Total cache: {len(cache)} entries")
    
    # Verify encoding
    verify = json.loads(cache_path.read_text(encoding="utf-8"))
    sample_keys = list(verify.keys())[:3]
    print("Sample keys:", sample_keys)

if __name__ == "__main__":
    asyncio.run(main())
