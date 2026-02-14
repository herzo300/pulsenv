"""Inspect new dataset structures"""
import json

with open('opendata_full.json', 'r', encoding='utf-8') as f:
    d = json.load(f)

# Budget datasets
for key in ['budgetbulletin', 'budgetinfo', 'budgetreport']:
    rows = d.get(key, {}).get('rows', [])
    print(f"\n=== {key}: {len(rows)} rows ===")
    if rows:
        print(f"  Fields: {list(rows[0].keys())}")
        for r in rows[:3]:
            print(f"  {json.dumps(r, ensure_ascii=False)[:200]}")

# Agreements (contracts)
for key in ['agreementsek', 'agreementsgchp', 'agreementskjc', 'agreementsdai', 'agreementsdkr']:
    rows = d.get(key, {}).get('rows', [])
    print(f"\n=== {key}: {len(rows)} rows ===")
    if rows:
        print(f"  Fields: {list(rows[0].keys())}")
        for r in rows[:2]:
            print(f"  {json.dumps(r, ensure_ascii=False)[:250]}")

# Property
for key in ['propertyregisterlands', 'propertyregistermovableproperty', 'propertyregisterrealestate', 'propertyregisterstoks', 'infoprivatization', 'inforent']:
    rows = d.get(key, {}).get('rows', [])
    print(f"\n=== {key}: {len(rows)} rows ===")
    if rows:
        print(f"  Fields: {list(rows[0].keys())}")
        for r in rows[:1]:
            print(f"  {json.dumps(r, ensure_ascii=False)[:250]}")

# Business
for key in ['businessinfo', 'msgsmp', 'advertisingconstructions', 'listcommunicationequipment']:
    rows = d.get(key, {}).get('rows', [])
    print(f"\n=== {key}: {len(rows)} rows ===")
    if rows:
        print(f"  Fields: {list(rows[0].keys())}")
        for r in rows[:1]:
            print(f"  {json.dumps(r, ensure_ascii=False)[:250]}")

# Other new
for key in ['landplotsreestr', 'buildreestr', 'placesad', 'otguid', 'ogobsor', 'prglistag', 'tarif', 'demography']:
    rows = d.get(key, {}).get('rows', [])
    print(f"\n=== {key}: {len(rows)} rows ===")
    if rows:
        print(f"  Fields: {list(rows[0].keys())}")
        for r in rows[:2]:
            print(f"  {json.dumps(r, ensure_ascii=False)[:250]}")
