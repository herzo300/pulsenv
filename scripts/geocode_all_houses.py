# scripts/geocode_all_houses.py
import asyncio
import sys
import json
import os
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from services.business.geo_service import get_coordinates, _normalize_key

def clean_address(street, building):
    street = street.strip()
    building = building.strip()
    
    # Check if street already has a type prefix
    street_lower = street.lower()
    has_prefix = any(
        street_lower.startswith(p)
        for p in ["улица ", "ул. ", "ул ", "проспект ", "пр. ", "пр-т ", "бульвар ", "б-р ", "проезд ", "переулок ", "пер. ", "мкр.", "мкр ", "микрорайон "]
    )
    
    prefix = "" if has_prefix else "ул. "
    return f"{prefix}{street} {building}, Нижневартовск"

async def geocode_single(addr):
    try:
        # 1. Try standard query
        coords = await get_coordinates(addr)
        if not coords and "корп." in addr:
            # Fallback: replace "корп." with "/" for Photon/Nominatim
            fallback_addr = addr.replace(" корп. ", "/")
            coords = await get_coordinates(fallback_addr)
        return addr, coords
    except Exception as e:
        return addr, None

async def main():
    print("Starting parallel geocoding of all UK houses...")
    catalog_path = Path("data/uk_catalog.json")
    if not catalog_path.exists():
        print("Error: data/uk_catalog.json does not exist!")
        return
        
    with open(catalog_path, encoding="utf-8") as f:
        d = json.load(f)
        
    rows = d.get("listoumd", {}).get("rows", []) if isinstance(d, dict) else d
    
    # Clean the existing geocode cache from corrupted keys (containing \uFFFD)
    cache_path = Path("data/geocode_cache.json")
    cache = {}
    if cache_path.exists():
        try:
            raw_cache = json.loads(cache_path.read_text(encoding="utf-8"))
            cache = {k: v for k, v in raw_cache.items() if "\uFFFD" not in k}
            print(f"Loaded existing cache. Kept {len(cache)} uncorrupted entries.")
        except Exception as e:
            print(f"Error loading cache: {e}. Starting fresh.")
            
    # Write back clean cache
    cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
    
    unique_addresses = []
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
                address = clean_address(street, building)
                norm = _normalize_key(address)
                if norm not in seen:
                    seen.add(norm)
                    unique_addresses.append(address)
                    
    print(f"Found {len(unique_addresses)} unique house addresses.")
    
    # Filter out already cached addresses
    to_geocode = [addr for addr in unique_addresses if _normalize_key(addr) not in cache]
    print(f"Already cached: {len(unique_addresses) - len(to_geocode)}. To geocode: {len(to_geocode)}")
    
    # Enable Photon for fast responses
    os.environ["GEO_ENABLE_PHOTON"] = "true"
    
    success_count = 0
    fail_count = 0
    
    batch_size = 20
    for i in range(0, len(to_geocode), batch_size):
        batch = to_geocode[i:i+batch_size]
        print(f"Processing batch {i//batch_size + 1}/{(len(to_geocode)-1)//batch_size + 1} (size {len(batch)})...")
        
        # Concurrently resolve this batch
        tasks = [geocode_single(addr) for addr in batch]
        results = await asyncio.gather(*tasks)
        
        for addr, coords in results:
            safe_addr = addr.encode('ascii', 'xmlcharrefreplace').decode('ascii')
            if coords:
                # Cache is written to dynamically inside remember_coordinates, but let's double check
                success_count += 1
            else:
                print(f"  FAILED: {safe_addr}")
                fail_count += 1
                
        # Brief pause between batches to respect the external service limits
        await asyncio.sleep(0.5)
        
    # Final cache count check
    if cache_path.exists():
        try:
            final_cache = json.loads(cache_path.read_text(encoding="utf-8"))
            print(f"Final cache size on disk: {len(final_cache)}")
        except Exception:
            pass
            
    print(f"Geocoding complete. New geocoded: {success_count}, Failed: {fail_count}")

if __name__ == "__main__":
    asyncio.run(main())
