import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/all_reports_db.json", "r", encoding="utf-8") as f:
    reports = json.load(f)

for r in reports:
    if r['id'] >= 870:
        print(f"=== ID {r['id']} ===")
        print(f"Title:    {r['title']}")
        print(f"Address:  {r['address']}")
        print(f"Coords:   {r['lat']}, {r['lng']}")
        print(f"Source:   {r['source']}")
        print(f"Desc:     {r['description']}")
        print()
