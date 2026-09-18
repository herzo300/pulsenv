#!/usr/bin/env python3
"""
CLI script to auto-import and synchronize all houses and buildings of Nizhnevartovsk.
Usage: python scripts/auto_import_houses.py
"""
import sys
import logging
from pathlib import Path

# Add project root to sys.path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

def main():
    from services.Backend.services.house_import_service import HouseImportService
    print("🏢 Starting automated Nizhnevartovsk house registry import & sync...")
    result = HouseImportService.import_all_sources()
    print(f"✅ Import complete! Total houses in database: {result['total_houses_count']}")
    print(f"📁 Backend JSON: {result['backend_json_path']}")
    print(f"📁 Frontend Dart: {result['frontend_dart_path']}")
    print("Sample addresses:")
    for h in result["sample_houses"]:
        print(f"  - {h['address']} ({h['lat']}, {h['lng']})")

if __name__ == "__main__":
    main()
