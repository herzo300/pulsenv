"""Загрузить все датасеты с таймаутом"""
import asyncio, sys, os, json, logging
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ['PYTHONIOENCODING'] = 'utf-8'
logging.basicConfig(level=logging.INFO, format='%(message)s')

from dotenv import load_dotenv
load_dotenv()
import httpx

API_KEY = os.getenv("NV_OPENDATA_API_KEY", "")
BASE = "https://data.n-vartovsk.ru/api/v1"
DATA_FILE = "opendata_full.json"

# All 72 datasets
DATASETS = {
    "listoumd": "8603032896-listoumd",
    "agstruct": "8603032896-agstruct",
    "agphonedir": "8603032896-agphonedir",
    "uchgkhservices": "8603032896-uchgkhservices",
    "tarif": "8603032896-tarif",
    "wastecollection": "8603032896-wastecollection",
    "buildlist": "8603032896-buildlist",
    "uchdou": "8603032896-uchdou",
    "uchou": "8603032896-uchou",
    "uchsport": "8603032896-uchsport",
    "uchculture": "8603032896-uchculture",
    "uchsportsection": "8603032896-uchsportsection",
    "topnameboys": "8603032896-topnameboys",
    "topnamegirls": "8603032896-topnamegirls",
    "averagesalary": "8603032896-averagesalary",
    "roadgasstationprice": "8603032896-roadgasstationprice",
    "mspsupport": "8603032896-mspsupport",
    "placespk": "8603032896-placespk",
    "placessg": "8603032896-placessg",
    "territoryplans": "8603032896-territoryplans",
    "busroute": "8603032896-busroute",
    "busstation": "8603032896-busstation",
    "demography": "8603032896-demography",
    "roadgasstation": "8603032896-roadgasstation",
    "roadservice": "8603032896-roadservice",
    "roadworks": "8603032896-roadworks",
    "buildpermission": "8603032896-buildpermission",
    "buildreestr": "8603032896-buildreestr",
    "landplotsreestr": "8603032896-landplotsreestr",
    "dostupnayasreda": "8603032896-dostupnayasreda",
    "publichearing": "8603032896-publichearing",
    "stvpgmu": "8603032896-stvpgmu",
    "budgetbulletin": "8603032896-budgetbulletin",
    "budgetinfo": "8603032896-budgetinfo",
    "budgetreport": "8603032896-budgetreport",
    "agreementsdai": "8603032896-agreementsdai",
    "agreementsdkr": "8603032896-agreementsdkr",
    "agreementsek": "8603032896-agreementsek",
    "agreementsgchp": "8603032896-agreementsgchp",
    "agreementsiip": "8603032896-agreementsiip",
    "agreementsik": "8603032896-agreementsik",
    "agreementskjc": "8603032896-agreementskjc",
    "agreementsrip": "8603032896-agreementsrip",
    "agreementssp": "8603032896-agreementssp",
    "agreementszpk": "8603032896-agreementszpk",
    "propertyregisterlands": "8603032896-propertyregisterlands",
    "propertyregistermovableproperty": "8603032896-propertyregistermovableproperty",
    "propertyregisterrealestate": "8603032896-propertyregisterrealestate",
    "propertyregisterstoks": "8603032896-propertyregisterstoks",
    "infoprivatization": "8603032896-infoprivatization",
    "inforent": "8603032896-inforent",
    "businessevents": "8603032896-businessevents",
    "businessinfo": "8603032896-businessinfo",
    "msgsmp": "8603032896-msgsmp",
    "advertisingconstructions": "8603032896-advertisingconstructions",
    "listcommunicationequipment": "8603032896-listcommunicationequipment",
    "archiveexpertise": "8603032896-archiveexpertise",
    "archivelistag": "8603032896-archivelistag",
    "docag": "8603032896-docag",
    "docaglink": "8603032896-docaglink",
    "docagtext": "8603032896-docagtext",
    "prglistag": "8603032896-prglistag",
    "sitelenta": "8603032896-sitelenta",
    "sitenews": "8603032896-sitenews",
    "siterubrics": "8603032896-siterubrics",
    "photoreports": "8603032896-photoreports",
    "ogobsor": "8603032896-ogobsor",
    "otguid": "8603032896-otguid",
    "placesad": "8603032896-placesad",
    "uchcultureclubs": "8603032896-uchcultureclubs",
    "uchsporttrainers": "8603032896-uchsporttrainers",
    "uchoudod": "8603032896-uchoudod",
}

async def fetch_ds(client, key, ds_id, max_pages=5):
    """Fetch dataset with page limit"""
    all_rows = []
    for page in range(1, max_pages+1):
        url = f"{BASE}/{ds_id}/data?api_key={API_KEY}&ROWS=500&PAGE={page}"
        try:
            r = await client.get(url, headers={"User-Agent": "PulsGoroda/1.0"})
            if r.status_code != 200:
                break
            data = r.json()
            result = data.get("RESULT", {})
            rows = result.get("ROWS", [])
            if not rows:
                break
            all_rows.extend(rows)
            total_pages = result.get("META", {}).get("PAGE_TOTAL", 1)
            if page >= total_pages:
                break
        except Exception as e:
            print(f"  ERR {key} page {page}: {e}")
            break
    return all_rows

async def main():
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).isoformat()
    result = {}
    
    async with httpx.AsyncClient(timeout=20.0) as client:
        for key, ds_id in DATASETS.items():
            try:
                rows = await fetch_ds(client, key, ds_id, max_pages=10)
                result[key] = {"rows": rows, "meta": {"updated": now, "count": len(rows)}}
                print(f"  {key}: {len(rows)}")
            except Exception as e:
                result[key] = {"rows": [], "meta": {"updated": now, "count": 0}}
                print(f"  {key}: ERR {e}")
    
    result["_meta"] = {"updated_at": now, "datasets_count": len(DATASETS)}
    
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False)
    
    total = sum(len(v.get("rows",[])) for k,v in result.items() if k != "_meta")
    with_data = sum(1 for k,v in result.items() if k != "_meta" and len(v.get("rows",[])) > 0)
    print(f"\nDone: {len(result)-1} datasets, {with_data} with data, {total} total rows")

asyncio.run(main())
