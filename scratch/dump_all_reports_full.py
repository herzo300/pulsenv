import json

with open("scratch/all_reports_db.json", "r", encoding="utf-8") as f:
    reports = json.load(f)

print(f"Total reports: {len(reports)}")

# Let's inspect all reports created in recent days or all reports in DB
for r in reports:
    print(f"--- ID {r['id']} ---")
    print(f"Title:       {r['title']}")
    print(f"Address:     {r['address']}")
    print(f"Coords:      {r['lat']}, {r['lng']}")
    print(f"Category:    {r['category']}")
    print(f"Created at:  {r['created_at']}")
    print(f"Source:      {r.get('source')}")
    print(f"Channel:     {r.get('channel')}")
    print(f"Description: {r['description']}")
    print()
