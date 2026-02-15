"""Inspect UK MKD (houses) data"""
import json
with open("opendata_full.json", "r", encoding="utf-8") as f:
    data = json.load(f)
uk = data.get("listoumd", {}).get("rows", [])
# Check MKD field
for u in uk[:3]:
    mkd = u.get('MKD', '')
    print(f"{u.get('TITLESM','?')} | CNT={u.get('CNT',0)} | MKD type={type(mkd).__name__} | MKD[:200]={str(mkd)[:200]}")
    print()
