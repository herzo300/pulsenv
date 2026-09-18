# scripts/geocode_nominatim_local.py
import asyncio
import json
import os
import sys
import re
from pathlib import Path
import httpx
from urllib.parse import quote

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

def clean_building_number(num):
    num = num.strip().lower()
    num = re.sub(r"\s+", "", num)
    num = re.sub(r"корп\.", "", num)
    return num

async def geocode_nominatim(client, street, building):
    full_address = clean_address(street, building)
    q = quote(full_address)
    url = f"https://nominatim.openstreetmap.org/search?q={q}&format=jsonv2&limit=5&countrycodes=ru"
    
    try:
        r = await client.get(url)
        if r.status_code == 429:
            print("  Rate limited (HTTP 429). Need longer sleep.")
            return full_address, None, True
            
        if r.status_code != 200:
            return full_address, None, False
            
        data = r.json()
        if not data or not isinstance(data, list):
            return full_address, None, False
            
        expected_house = clean_building_number(building)
        
        # Look for a feature that matches the house number
        for item in data:
            lat = item.get("lat")
            lon = item.get("lon")
            if lat and lon:
                display_name = item.get("display_name", "").lower()
                # Confirm it is in Nizhnevartovsk
                if "нижневартовск" in display_name or "nizhnevartovsk" in display_name:
                    return full_address, (float(lat), float(lon)), False
                    
        # Fallback to the first result
        first = data[0]
        lat = first.get("lat")
        lon = first.get("lon")
        if lat and lon:
            return full_address, (float(lat), float(lon)), False
            
    except Exception as e:
        print(f"  Error geocoding {full_address}: {e}")
        
    return full_address, None, False

async def main():
    print("Starting sequential Nominatim geocoding of missing houses...")
    catalog_path = Path("data/uk_catalog.json")
    if not catalog_path.exists():
        print("Error: data/uk_catalog.json not found!")
        return
        
    with open(catalog_path, encoding="utf-8") as f:
        catalog_data = json.load(f)
        
    rows = catalog_data.get("listoumd", {}).get("rows", []) if isinstance(catalog_data, dict) else catalog_data
    
    # Load and clean cache
    cache_path = Path("data/geocode_cache.json")
    cache = {}
    if cache_path.exists():
        try:
            raw_cache = json.loads(cache_path.read_text(encoding="utf-8"))
            cache = {k: v for k, v in raw_cache.items() if "\uFFFD" not in k}
            print(f"Loaded existing cache. Kept {len(cache)} entries.")
        except Exception as e:
            print(f"Error loading cache: {e}. Starting fresh.")
            
    # Extract unique street-building items to geocode
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
                    
    print(f"Total unique houses in catalog: {len(unique_items)}")
    
    # Filter to only those not in cache
    to_geocode = [(s, b) for s, b in unique_items if normalize_key(clean_address(s, b)) not in cache]
    print(f"Already cached: {len(unique_items) - len(to_geocode)}. To geocode: {len(to_geocode)}")
    
    if not to_geocode:
        print("All houses are already geocoded and cached.")
        return
        
    headers = {"User-Agent": "PulsGorodaGeocoding/3.0 (contact@soobshio.ru)"}
    
    success_count = 0
    fail_count = 0
    
    async with httpx.AsyncClient(timeout=8.0, headers=headers) as client:
        for idx, (s, b) in enumerate(to_geocode):
            addr_key = clean_address(s, b)
            norm = normalize_key(addr_key)
            
            print(f"[{idx+1}/{len(to_geocode)}] Geocoding: {addr_key}...", end="", flush=True)
            
            # Request
            addr, coords, rate_limited = await geocode_nominatim(client, s, b)
            
            if rate_limited:
                print(" Sleeping for 10 seconds due to 429...")
                await asyncio.sleep(10.0)
                # Retry once
                addr, coords, rate_limited = await geocode_nominatim(client, s, b)
                
            if coords:
                cache[norm] = coords
                success_count += 1
                print(f" SUCCESS: {coords}")
            else:
                print(" FAILED")
                fail_count += 1
                
            # Periodic save
            if (success_count + fail_count) % 5 == 0:
                cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
                
            # Respect rate limit (Nominatim policy requires 1s min)
            await asyncio.sleep(1.3)
            
    # Final write to cache
    cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Completed! Success: {success_count}, Failed: {fail_count}")
    print(f"Total cache entries on disk: {len(cache)}")

if __name__ == "__main__":
    asyncio.run(main())
