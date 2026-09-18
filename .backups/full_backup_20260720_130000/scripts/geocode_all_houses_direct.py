# scripts/geocode_all_houses_direct.py
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
    # Normalize slash and corp indicators to 'k'
    num = num.replace("корп.", "k").replace("корп", "k").replace("корпус", "k").replace("/", "k")
    # Replace common Cyrillic letters with Latin equivalents
    replacements = {
        'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'е': 'e', 'к': 'k', 'м': 'm', 'н': 'n',
        'о': 'o', 'р': 'r', 'с': 'c', 'т': 't', 'у': 'u', 'х': 'x'
    }
    for cyr, lat in replacements.items():
        num = num.replace(cyr, lat)
    return num

def get_query_variations(street, building):
    variations = []
    b_clean = building.strip()
    s_clean = street.strip()
    
    variations.append(clean_address(s_clean, b_clean))
    
    if "," in s_clean:
        parts = [p.strip() for p in s_clean.split(",")]
        if len(parts) == 2:
            variations.append(f"{parts[1]} {b_clean}, {parts[0]}, Нижневартовск")
            variations.append(f"{parts[1]} {b_clean}, Нижневартовск")
            
    if "корп." in b_clean.lower() or "корпус" in b_clean.lower():
        b_k = re.sub(r"корп\.?\s*", "к", b_clean, flags=re.IGNORECASE)
        variations.append(clean_address(s_clean, b_k))
        b_slash = re.sub(r"корп\.?\s*", "/", b_clean, flags=re.IGNORECASE)
        variations.append(clean_address(s_clean, b_slash))
        
    return list(dict.fromkeys(variations))

async def geocode_address(client, street, building):
    queries = get_query_variations(street, building)
    primary_address = clean_address(street, building)
    expected_house = clean_building_number(building)
    
    for q_addr in queries:
        q = quote(q_addr)
        url = f"https://photon.komoot.io/api/?q={q}&limit=5"
        try:
            r = await client.get(url)
            if r.status_code != 200:
                continue
                
            data = r.json()
            features = data.get("features", [])
            if not features:
                continue
                
            # Look for a feature that matches the house number
            for feature in features:
                props = feature.get("properties", {})
                geom = feature.get("geometry", {})
                coords = geom.get("coordinates", [])
                
                if len(coords) >= 2:
                    housenumber = str(props.get("housenumber", "")).strip().lower()
                    clean_house = clean_building_number(housenumber)
                    
                    # Check house match
                    if clean_house == expected_house or expected_house in clean_house:
                        return primary_address, (coords[1], coords[0])
                        
            # Fallback to the first feature if no exact house number matched but it is a house/building
            first_feat = features[0]
            geom = first_feat.get("geometry", {})
            coords = geom.get("coordinates", [])
            if len(coords) >= 2:
                return primary_address, (coords[1], coords[0])
        except Exception:
            pass
            
    return primary_address, None

async def main():
    print("Starting fast geocoding of all UK houses...")
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
            print(f"Loaded existing cache. Kept {len(cache)} uncorrupted entries.")
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
                    # Keep raw street and building for cleaner geocoding
                    unique_items.append((street, building))
                    
    print(f"Total unique houses in catalog: {len(unique_items)}")
    
    # Filter to only those not in cache
    to_geocode = [(s, b) for s, b in unique_items if normalize_key(clean_address(s, b)) not in cache]
    print(f"Already cached: {len(unique_items) - len(to_geocode)}. To geocode: {len(to_geocode)}")
    
    if not to_geocode:
        print("All houses are already geocoded and cached.")
        return
        
    headers = {"User-Agent": "PulsGoroda/2.0 Geocoder"}
    
    success_count = 0
    fail_count = 0
    
    async with httpx.AsyncClient(timeout=10.0, headers=headers) as client:
        batch_size = 30
        for i in range(0, len(to_geocode), batch_size):
            batch = to_geocode[i:i+batch_size]
            print(f"Geocoding batch {i//batch_size + 1}/{(len(to_geocode)-1)//batch_size + 1} (size {len(batch)})...")
            
            tasks = [geocode_address(client, s, b) for s, b in batch]
            results = await asyncio.gather(*tasks)
            
            for addr, coords in results:
                norm = normalize_key(addr)
                safe_addr = addr.encode('ascii', 'xmlcharrefreplace').decode('ascii')
                if coords:
                    cache[norm] = coords
                    success_count += 1
                else:
                    print(f"  FAILED: {safe_addr}")
                    fail_count += 1
                    
            # Periodically write cache in case of interruptions
            cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
            
            await asyncio.sleep(0.3)
            
    # Final write to cache
    cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Completed! Success: {success_count}, Failed: {fail_count}")
    print(f"Total cache entries on disk: {len(cache)}")

if __name__ == "__main__":
    asyncio.run(main())
