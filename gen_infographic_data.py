"""Generate infographic_data.json from opendata_full.json — all 72 datasets"""
import json, os, re
from datetime import datetime, timezone

DATA_FILE = "opendata_full.json"
OUT_FILE = "infographic_data.json"

with open(DATA_FILE, "r", encoding="utf-8") as f:
    d = json.load(f)

meta = d.get("_meta", {})
info = {"updated_at": meta.get("updated_at", "")[:10]}

def rows(key):
    return d.get(key, {}).get("rows", [])

def safe_int(v):
    try: return int(v)
    except: return 0

def safe_float(v):
    try: return float(str(v).replace(",", ".").replace(" ", ""))
    except: return 0.0

def strip_html(s):
    if not s: return ""
    return re.sub(r'<[^>]+>', '', str(s)).strip()[:200]

# ═══ FUEL ═══
gas = rows("roadgasstationprice")
fp = {}
for fk, fn in [("AI92", "АИ-92"), ("AI95EURO", "АИ-95"), ("DTZIMA", "ДТ зимнее"), ("GAZ", "Газ")]:
    vals = [g[fk] for g in gas if g.get(fk)]
    if vals:
        fp[fn] = {"min": round(min(vals), 1), "max": round(max(vals), 1),
                  "avg": round(sum(vals) / len(vals), 1), "count": len(vals)}
fuel_date = gas[0].get("DAT", "") if gas else ""
info["fuel"] = {"date": fuel_date, "stations": len(gas), "prices": fp}

# АЗС
azs = rows("roadgasstation")
info["azs"] = [{"name": a.get("NUM", ""), "address": a.get("ADDRESS", ""),
                "org": a.get("ORG", ""), "tel": a.get("TEL", "")} for a in azs[:15]]

# ═══ УК ═══
uk = rows("listoumd")
top_uk = sorted(uk, key=lambda x: safe_int(x.get("CNT", 0)), reverse=True)[:10]
info["uk"] = {"total": len(uk),
              "houses": sum(safe_int(u.get("CNT", 0)) for u in uk),
              "top": [{"name": u.get("TITLESM", ""), "houses": safe_int(u.get("CNT", 0))} for u in top_uk]}

# ═══ EDUCATION ═══
sections = rows("uchsportsection")
dou = rows("uchdou")
ou = rows("uchou")
info["education"] = {
    "kindergartens": len(dou), "schools": len(ou),
    "culture": len(rows("uchculture")),
    "sport_orgs": len(rows("uchsport")),
    "sections": len(sections),
    "sections_free": sum(1 for s in sections if s.get("PAY") == "Бюджетная группа"),
    "sections_paid": sum(1 for s in sections if s.get("PAY") == "Платная группа"),
    "dod": len(rows("uchoudod")),
}

# ═══ WASTE ═══
waste = rows("wastecollection")
wg = {}
for w in waste:
    g = w.get("GROUP", "")
    wg[g] = wg.get(g, 0) + 1
info["waste"] = {"total": len(waste),
                 "groups": [{"name": g, "count": c} for g, c in sorted(wg.items(), key=lambda x: -x[1])]}

# ═══ NAMES ═══
boys = rows("topnameboys")
girls = rows("topnamegirls")
info["names"] = {
    "boys": [{"n": b["TITLE"], "c": safe_int(b["CNT"])}
             for b in sorted(boys, key=lambda x: safe_int(x.get("CNT", 0)), reverse=True)[:10]],
    "girls": [{"n": g["TITLE"], "c": safe_int(g["CNT"])}
              for g in sorted(girls, key=lambda x: safe_int(x.get("CNT", 0)), reverse=True)[:10]],
}

# ═══ GKH ═══
gkh = rows("uchgkhservices")
info["gkh"] = [{"name": g["TITLE"], "phone": g.get("TEL", "")} for g in gkh]

# ═══ TARIFFS ═══
tarif = rows("tarif")
info["tariffs"] = [{"title": t.get("TITLE", ""), "desc": strip_html(t.get("DESCRIPTION", ""))[:100]} for t in tarif[:8]]

# ═══ TRANSPORT ═══
bus_routes = rows("busroute")
bus_stops = rows("busstation")
muni = [b for b in bus_routes if "Муниципальный" in str(b.get("TYPE", ""))]
info["transport"] = {
    "routes": len(bus_routes), "stops": len(bus_stops),
    "municipal": len(muni), "commercial": len(bus_routes) - len(muni),
    "routes_list": [{"num": b.get("NUM", ""), "title": b.get("TITLE", ""),
                     "start": b.get("ROUTE_START", ""), "end": b.get("ROUTE_END", "")}
                    for b in bus_routes[:15]],
}

# ═══ ROAD SERVICE ═══
rs = rows("roadservice")
rs_types = {}
for r in rs:
    t = r.get("TYPE", "Прочее")
    rs_types[t] = rs_types.get(t, 0) + 1
info["road_service"] = {"total": len(rs),
                        "types": [{"name": k, "count": v} for k, v in sorted(rs_types.items(), key=lambda x: -x[1])]}

# ═══ ROAD WORKS ═══
rw = rows("roadworks")
info["road_works"] = {"total": len(rw),
                      "items": [{"title": x.get("TITLE", "")[:100]} for x in rw[:8]]}

# ═══ BUILDING (с годовой динамикой) ═══
bp = rows("buildpermission")
bl = rows("buildlist")
br = rows("buildreestr")
bp_by_year = {}
for b in bp:
    dat = b.get("DAT", "")
    if dat and len(dat) >= 4:
        y = dat[:4]
        try:
            yi = int(y)
            if 2000 <= yi <= 2030:
                bp_by_year[yi] = bp_by_year.get(yi, 0) + 1
        except:
            pass
bp_trend = [{"year": y, "count": c} for y, c in sorted(bp_by_year.items())]
info["building"] = {
    "permits": len(bp), "objects": len(bl), "reestr": len(br),
    "permits_trend": bp_trend[-10:],
}

# ═══ NEWS (с годовой динамикой) ═══
news_rows = rows("sitelenta") + rows("sitenews")
news_by_year = {}
for n in news_rows:
    dat = n.get("DAT", "")
    if dat and len(dat) >= 4:
        y = dat[-4:] if "." in dat else dat[:4]
        try:
            yi = int(y)
            if 2015 <= yi <= 2030:
                news_by_year[yi] = news_by_year.get(yi, 0) + 1
        except:
            pass
news_trend = [{"year": y, "count": c} for y, c in sorted(news_by_year.items())]

# ═══ LAND PLOTS ═══
lp = rows("landplotsreestr")
info["land_plots"] = {"total": len(lp),
                      "items": [{"address": x.get("ADDRESS", "")[:80], "square": x.get("SQUARE", "")} for x in lp[:5]]}

# ═══ ACCESSIBILITY ═══
ds_items = rows("dostupnayasreda")
ds_groups = {}
for item in ds_items:
    g = item.get("GROUP_TITLE", "Прочее")
    ds_groups[g] = ds_groups.get(g, 0) + 1
info["accessibility"] = {"total": len(ds_items),
                         "groups": [{"name": k, "count": v} for k, v in sorted(ds_groups.items(), key=lambda x: -x[1])]}

# ═══ CULTURE CLUBS ═══
clubs = rows("uchcultureclubs")
free_clubs = sum(1 for c in clubs if c.get("PAY") == "бесплатно")
info["culture_clubs"] = {"total": len(clubs), "free": free_clubs, "paid": len(clubs) - free_clubs,
                         "items": [{"name": c.get("TITLE", ""), "age": f"{c.get('AGE_START', '')}-{c.get('AGE_END', '')}",
                                    "pay": c.get("PAY", "")} for c in clubs[:12]]}

# ═══ TRAINERS ═══
info["trainers"] = {"total": len(rows("uchsporttrainers"))}

# ═══ SALARY (с годовой динамикой) ═══
salary = rows("averagesalary")
years = sorted(set(s.get("YEAR") for s in salary if s.get("YEAR") and s.get("YEAR") > 0))
sal_by_year = {}
for s in salary:
    y = s.get("YEAR", 0)
    if y <= 0:
        continue
    sv = s.get("SALARY", "0")
    try:
        v = float(str(sv).replace(",", ".").replace(" ", ""))
        if v > 0:
            sal_by_year.setdefault(y, []).append(v)
    except:
        pass
sal_trend = []
for y in sorted(sal_by_year.keys()):
    vals = sal_by_year[y]
    sal_trend.append({"year": y, "avg": round(sum(vals) / len(vals), 1), "count": len(vals)})
# Growth
sal_growth = 0
if len(sal_trend) >= 2:
    sal_growth = round((sal_trend[-1]["avg"] / sal_trend[0]["avg"] - 1) * 100, 1)
info["salary"] = {
    "total": len(salary), "years": years[-8:] if years else [],
    "trend": sal_trend[-8:],
    "growth_pct": sal_growth,
    "latest_avg": sal_trend[-1]["avg"] if sal_trend else 0,
}

# ═══ PUBLIC HEARINGS (с годовой динамикой) ═══
ph = rows("publichearing")
ph_by_year = {}
for p in ph:
    dat = p.get("DAT", "")
    if dat and len(dat) >= 4:
        y = dat[-4:] if "." in dat else dat[:4]
        try:
            yi = int(y)
            if 2010 <= yi <= 2030:
                ph_by_year[yi] = ph_by_year.get(yi, 0) + 1
        except:
            pass
ph_trend = [{"year": y, "count": c} for y, c in sorted(ph_by_year.items())]
info["hearings"] = {
    "total": len(ph),
    "trend": ph_trend[-8:],
    "recent": [{"date": h.get("DAT", ""), "title": strip_html(h.get("TITLE", ""))[:100]} for h in ph[:5]],
}

# ═══ GMU PHONES ═══
gmu = rows("stvpgmu")
info["gmu_phones"] = [{"org": g.get("TITLE", "")[:60], "tel": g.get("TEL", "")} for g in gmu[:10]]

# ═══ DEMOGRAPHY ═══
demo = rows("demography")
info["demography"] = [{"marriages": d.get("MARRIAGES"), "birth": d.get("BIRTH"),
                       "boys": d.get("BOYS"), "girls": d.get("GIRLS"), "date": d.get("DAT")} for d in demo if d.get("BIRTH") != "-"]

# ═══════════════════════════════════════════
# ═══ BUDGET (БЮДЖЕТ) — КЛЮЧЕВОЙ БЛОК ═══
# ═══════════════════════════════════════════

# Budget bulletins
bb = rows("budgetbulletin")
info["budget_bulletins"] = {"total": len(bb),
    "items": [{"title": b.get("TITLE",""), "desc": b.get("DESCRIPTION",""), "url": b.get("URL","")} for b in bb[:10]]}

# Budget info
bi = rows("budgetinfo")
info["budget_info"] = {"total": len(bi),
    "items": [{"title": b.get("TITLE",""), "desc": b.get("DESCRIPTION",""), "url": b.get("URL","")} for b in bi[:10]]}

# ═══ AGREEMENTS (КОНТРАКТЫ) ═══
all_agreements = []
agr_types = {
    "agreementsek": "Энергосервис",
    "agreementsgchp": "ГЧП",
    "agreementskjc": "КЖЦ",
    "agreementsdai": "Аренда имущества",
    "agreementsdkr": "Капремонт",
    "agreementsiip": "Инвестпроекты",
    "agreementsik": "Инвестконтракты",
    "agreementsrip": "РИП",
    "agreementssp": "Соцпартнёрство",
    "agreementszpk": "ЗПК",
}
total_summ = 0
total_inv = 0
total_gos = 0
agr_by_type = {}
for key, type_name in agr_types.items():
    agr_rows = rows(key)
    agr_by_type[type_name] = len(agr_rows)
    for a in agr_rows:
        summ = safe_float(a.get("SUMM", 0))
        vol_inv = safe_float(a.get("VOLUME_INV", 0))
        vol_gos = safe_float(a.get("VOLUME_GOS", 0))
        total_summ += summ
        total_inv += vol_inv
        total_gos += vol_gos
        if a.get("TITLE") or a.get("DESCRIPTION"):
            all_agreements.append({
                "type": type_name,
                "title": (a.get("TITLE") or "")[:80],
                "desc": strip_html(a.get("DESCRIPTION", ""))[:100],
                "org": (a.get("ORG") or "")[:60],
                "date": a.get("DAT", ""),
                "summ": summ,
                "vol_inv": vol_inv,
                "vol_gos": vol_gos,
                "year": a.get("YEAR", ""),
            })

# Sort by summ descending
all_agreements.sort(key=lambda x: x["summ"], reverse=True)

info["agreements"] = {
    "total": sum(agr_by_type.values()),
    "total_summ": round(total_summ, 2),
    "total_inv": round(total_inv, 2),
    "total_gos": round(total_gos, 2),
    "by_type": [{"name": k, "count": v} for k, v in sorted(agr_by_type.items(), key=lambda x: -x[1]) if v > 0],
    "top": all_agreements[:15],
}

# ═══ PROPERTY (ИМУЩЕСТВО) ═══
pr_lands = rows("propertyregisterlands")
pr_movable = rows("propertyregistermovableproperty")
pr_realestate = rows("propertyregisterrealestate")
pr_stoks = rows("propertyregisterstoks")
priv = rows("infoprivatization")
rent = rows("inforent")

info["property"] = {
    "lands": len(pr_lands),
    "movable": len(pr_movable),
    "realestate": len(pr_realestate),
    "stoks": len(pr_stoks),
    "privatization": len(priv),
    "rent": len(rent),
    "total": len(pr_lands) + len(pr_movable) + len(pr_realestate) + len(pr_stoks),
}

# ═══ BUSINESS ═══
binfo = rows("businessinfo")
msgsmp = rows("msgsmp")
info["business"] = {
    "info": len(binfo),
    "smp_messages": len(msgsmp),
    "events": len(rows("businessevents")),
}

# ═══ ADVERTISING ═══
adv = rows("advertisingconstructions")
info["advertising"] = {"total": len(adv)}

# ═══ COMMUNICATION EQUIPMENT ═══
comm = rows("listcommunicationequipment")
info["communication"] = {"total": len(comm)}

# ═══ ARCHIVE ═══
arch_exp = rows("archiveexpertise")
arch_list = rows("archivelistag")
info["archive"] = {"expertise": len(arch_exp), "list": len(arch_list)}

# ═══ DOCUMENTS ═══
docag = rows("docag")
doclink = rows("docaglink")
doctext = rows("docagtext")
info["documents"] = {"docs": len(docag), "links": len(doclink), "texts": len(doctext)}

# ═══ PROGRAMS ═══
prg = rows("prglistag")
info["programs"] = {"total": len(prg),
    "items": [{"title": strip_html(p.get("TITLE",""))[:100]} for p in prg[:5]]}

# ═══ NEWS ═══
info["news"] = {"total": len(news_rows),
    "rubrics": len(rows("siterubrics")),
    "photos": len(rows("photoreports")),
    "trend": news_trend[-5:]}

# ═══ PLACES ═══
placesad = rows("placesad")
info["ad_places"] = {"total": len(placesad)}

# ═══ TERRITORY PLANS ═══
tp = rows("territoryplans")
info["territory_plans"] = {"total": len(tp)}

# ═══ LABOR SAFETY ═══
otguid = rows("otguid")
info["labor_safety"] = {"total": len(otguid)}

# ═══ APPEALS ═══
ogobsor = rows("ogobsor")
info["appeals"] = {"total": len(ogobsor)}

# ═══ MSP SUPPORT ═══
msp = rows("mspsupport")
info["msp"] = {"total": len(msp),
    "items": [{"title": m.get("TITLE","")[:80]} for m in msp[:10]]}

# ═══ COUNTS ═══
info["counts"] = {
    "construction": len(rows("buildlist")),
    "phonebook": len(rows("agphonedir")),
    "admin": len(rows("agstruct")),
    "sport_places": len(rows("placessg")),
    "mfc": len(rows("placespk")),
    "msp": len(msp),
    "trainers": len(rows("uchsporttrainers")),
    "bus_routes": len(bus_routes),
    "bus_stops": len(bus_stops),
    "accessibility": len(ds_items),
    "culture_clubs": len(clubs),
    "hearings": len(ph),
    "permits": len(bp),
    "property_total": info["property"]["total"],
    "agreements_total": info["agreements"]["total"],
    "budget_docs": len(bb) + len(bi),
    "privatization": len(priv),
    "rent": len(rent),
    "advertising": len(adv),
    "documents": len(docag),
    "archive": len(arch_list),
    "business_info": len(binfo),
    "smp_messages": len(msgsmp),
    "news": info["news"]["total"],
    "territory_plans": len(tp),
}

info["datasets_total"] = 72
info["datasets_with_data"] = sum(1 for k in d if k != "_meta" and len(d[k].get("rows", [])) > 0)

# Save
with open(OUT_FILE, "w", encoding="utf-8") as f:
    json.dump(info, f, ensure_ascii=False, indent=None, separators=(",", ":"))

print(f"Generated {OUT_FILE}: {os.path.getsize(OUT_FILE)} bytes, {len(info)} keys")
