import json

with open("scratch/all_reports_db.json", "r", encoding="utf-8") as f:
    reports = json.load(f)

print(f"Total reports: {len(reports)}")
omskaya_or_bad = []
for r in reports:
    addr = r.get('address') or ''
    title = r.get('title') or ''
    desc = r.get('description') or ''
    lat = r.get('lat')
    lng = r.get('lng')
    print(f"ID {r['id']:3d} | Addr: {addr:35s} | Coords: ({lat}, {lng}) | Title: {title}")
    if 'омск' in addr.lower() or 'вартовск' in addr.lower() or not addr:
        omskaya_or_bad.append(r)

print(f"\n--- BAD/GENERIC REPORTS COUNT: {len(omskaya_or_bad)} ---")
for r in omskaya_or_bad:
    print(f"\n[ID {r['id']}] Title: {r['title']}")
    print(f"Current Addr: {r['address']} | Coords: {r['lat']}, {r['lng']}")
    print(f"Description: {r['description']}")
