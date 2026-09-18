import sys
import os
import re
import asyncio
from datetime import datetime, timedelta
from sqlalchemy import select

# Ensure root of project is in python path
sys.path.append(os.getcwd())

from services.data_layer.database import SessionLocal
from services.data_layer.models import Report
from services.business.geo_service import get_coordinates

def parse_districts(file_path):
    districts = {}
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        # Regex for DistrictData: DistrictData(id: '...', name: '...', polygon: const [...] or [...])
        pattern = r"DistrictData\(\s*id:\s*'(.*?)',\s*name:\s*'(.*?)',\s*polygon:\s*(?:const\s*)?\[([\s\S]*?)\]"
        for m in re.finditer(pattern, content):
            name = m.group(2)
            poly_str = m.group(3)
            
            # Extract lat/lng
            pts = re.findall(r"LatLng\(([-.\d]+),\s*([-.\d]+)\)", poly_str)
            if pts:
                lats = [float(p[0]) for p in pts]
                lngs = [float(p[1]) for p in pts]
                centroid = (sum(lats) / len(lats), sum(lngs) / len(lngs))
                districts[name.lower()] = centroid
    except Exception as e:
        print(f"Error parsing {file_path}: {e}")
    return districts

def normalize_name(text):
    text = text.lower()
    text = re.sub(r"-й|-я|-е|-ые|-ый|-ой", "", text)  # remove suffixes
    text = re.sub(r"\bмкр\b|микрорайон|район|улица|ул\.", "", text)  # remove keywords
    text = re.sub(r"\s+", "", text)  # remove whitespace
    return text.strip()

def find_matching_district(address, district_map):
    if not address:
        return None
    norm_addr = normalize_name(address)
    for dist_name, centroid in district_map.items():
        norm_dist = normalize_name(dist_name)
        if norm_dist and norm_dist in norm_addr:
            return centroid
    return None

def has_house_number(address):
    if not address:
        return False
    # matches numbers like 15, 10a, 2/4, 9п
    return bool(re.search(r"\b\d+[a-zа-я]?(?:\/\d+)?\b", address))

async def main():
    print("Loading districts...")
    nv_districts = parse_districts("services/Frontend/lib/data/district_data.dart")
    nsk_districts = parse_districts("services/Frontend/lib/data/novosibirsk_district_data.dart")
    print(f"Loaded {len(nv_districts)} NV districts, {len(nsk_districts)} NSK districts.")

    session = SessionLocal()
    
    # Fetch reports from the last 30 days
    cutoff_date = datetime.utcnow() - timedelta(days=30)
    query = select(Report).where(Report.created_at >= cutoff_date)
    reports = session.scalars(query).all()
    print(f"Checking {len(reports)} reports created since {cutoff_date}...")

    updated_count = 0
    
    for report in reports:
        address = report.address or ""
        city = report.city or "nizhnevartovsk"
        print(f"\nReport ID {report.id} | Address: '{address}' | City: {city}")
        
        # Select appropriate district map
        district_map = nsk_districts if city == "novosibirsk" else nv_districts
        city_center = (54.9885, 82.9207) if city == "novosibirsk" else (60.9344, 76.5531)
        
        target_coords = None
        
        if has_house_number(address):
            print("  Precise address format detected, trying forward geocoder...")
            # Try to geocode precise address
            try:
                coords = await get_coordinates(address, city=city)
                if coords:
                    target_coords = coords
                    print(f"  Geocoding success: {target_coords}")
                else:
                    print("  Geocoding failed, trying district centroid fallback...")
            except Exception as e:
                print(f"  Error geocoding: {e}")
        
        # If no precise geocode, check for microdistrict centroid
        if not target_coords:
            centroid = find_matching_district(address, district_map)
            if centroid:
                target_coords = centroid
                print(f"  Matched district centroid: {target_coords}")
            else:
                # Fallback to city center if completely vague
                target_coords = city_center
                print(f"  Vague address. Falling back to city center: {target_coords}")
                
        # Update if coordinates changed
        if target_coords:
            new_lat, new_lng = target_coords
            # Check if there is a meaningful difference
            if report.lat is None or report.lng is None or abs(report.lat - new_lat) > 0.0001 or abs(report.lng - new_lng) > 0.0001:
                report.lat = new_lat
                report.lng = new_lng
                session.add(report)
                updated_count += 1
                print(f"  -> Coords updated to {new_lat}, {new_lng}")
            else:
                print("  Coords are already correct.")

    if updated_count > 0:
        session.commit()
        print(f"\nSuccessfully updated {updated_count} reports.")
    else:
        print("\nNo reports needed coordinate updates.")
        
    session.close()

if __name__ == "__main__":
    asyncio.run(main())
