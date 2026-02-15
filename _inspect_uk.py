"""Inspect UK dataset for emails and structure"""
import json
with open("opendata_full.json", "r", encoding="utf-8") as f:
    data = json.load(f)
uk = data.get("listoumd", {}).get("rows", [])
print(f"Total UK: {len(uk)}")
if uk:
    print(f"Keys: {list(uk[0].keys())}")
    for u in uk[:5]:
        print(f"  {u.get('TITLESM','?')} | houses={u.get('CNT',0)} | email={u.get('EMAIL','')} | tel={u.get('TEL','')} | adr={u.get('ADR','')}")
    # Check which have emails
    with_email = [u for u in uk if u.get('EMAIL')]
    print(f"\nWith email: {len(with_email)}/{len(uk)}")
    for u in with_email[:10]:
        print(f"  {u.get('TITLESM','?')} → {u.get('EMAIL','')}")
