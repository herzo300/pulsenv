import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/all_reports_db.json", "r", encoding="utf-8") as f:
    reports = json.load(f)

print(f"Total reports in DB: {len(reports)}\n")

for r in reports:
    addr = r.get('address') or 'NO_ADDRESS'
    lat = r.get('lat')
    lng = r.get('lng')
    title = r.get('title') or ''
    desc = r.get('description') or ''
    
    print(f"ID {r['id']:3d} | [{addr}] | ({lat}, {lng})")
    print(f"   Title:  {title}")
    # print first 200 chars of desc
    clean_desc = desc.replace('\n', ' ')[:200]
    print(f"   Desc:   {clean_desc}")
    print(f"   Source: {r.get('source')} | Created: {r.get('created_at')}")
    print("-" * 70)
