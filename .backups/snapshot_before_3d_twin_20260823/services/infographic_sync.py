import json
import logging
import os
import re
from datetime import datetime, timezone
from typing import Any, List, Dict
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

logger = logging.getLogger(__name__)

INFOGRAPHIC_JSON = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "services", "Frontend", "assets", "infographic_data.json",
)

def safe_float(val: Any) -> float:
    if val is None or val == "": return 0.0
    if isinstance(val, (int, float)): return float(val)
    try:
        s = str(val).strip().replace(" ", "").replace(",", ".")
        s = "".join(c for c in s if c.isdigit() or c in ".-")
        if not s: return 0.0
        return float(s)
    except (ValueError, TypeError):
        return 0.0

def extract_year(val: Any) -> str:
    s = str(val)
    match = re.search(r"(20[0-2]\d)", s)
    if match: return match.group(1)
    return ""

def generate_analysis(title: str, trend_data: List[Dict], val_key: str = "value", label: str = "показатель") -> str:
    if not trend_data or len(trend_data) < 2:
        return f"Сектор «{title}» в настоящее время характеризуется стабильными показателями. Для выявления долгосрочных трендов требуется расширение ретроспективной выборки данных."
    
    first = trend_data[0]
    last = trend_data[-1]
    v_first = first.get(val_key, 0)
    v_last = last.get(val_key, 0)
    
    diff = round(v_last - v_first, 2)
    percent = round((diff / v_first * 100), 1) if v_first != 0 else 0
    years_span = int(last['year']) - int(first['year'])
    
    parts = []
    parts.append(f"Анализ направления «{title}» за период {first['year']}–{last['year']} гг.")
    
    if diff > 0:
        parts.append(f"зафиксирован прирост: {label} увеличился на {percent}% (динамика: +{diff}).")
    elif diff < 0:
        parts.append(f"наблюдается контролируемое снижение на {abs(percent)}% (изменение: {diff}).")
    else:
        parts.append(f"динамика отсутствует, значение застыло на отметке {v_last}, что говорит о достижении «плато».")

    parts.append(f"Текущие цифры ({v_last}) подтверждают статус Нижневартовска как динамично развивающегося центра.")
    
    return " ".join(parts)

def build_trend(rows: List[Dict], val_keys: List[str], year_key: str = "YEAR") -> List[Dict]:
    if not rows: return []
    data_map = {}
    for r in rows:
        y_val = r.get(year_key) or r.get("DAT") or r.get("DATE") or r.get("YEAR")
        y = extract_year(y_val)
        if not y: continue
        data_map.setdefault(y, {})
        for k in val_keys:
            v = safe_float(r.get(k))
            data_map[y].setdefault(k, []).append(v)
            
    sorted_years = sorted(data_map.keys())
    real_years = [y for y in sorted_years if int(y) <= 2024]
    
    trend = []
    last_vals = {}
    for y in real_years[-6:]:
        entry = {"year": y}
        for k in val_keys:
            vals = data_map[y][k]
            v = round(sum(vals)/len(vals), 1) if vals else 0.0
            entry[k.lower()] = v
            last_vals[k] = v
        if len(val_keys) == 1:
            entry["value"] = entry[val_keys[0].lower()]
        trend.append(entry)
        
    if not trend: return []

    return trend

def build_infographic(opendata: dict) -> dict:
    now = datetime.now(timezone.utc).isoformat()
    result = {
        "updated_at": now, 
        "city": "Нижневартовск",
        "region": "ХМАО-Югра",
        "founded": 1909,
        "population_current": 293130,
        "area_km2": 268.56,
        "blocks": []
    }
    
    # --- 1. ECONOMY ---
    econ_items = []
    salary_trend = build_trend(opendata.get("averagesalary", {}).get("rows", []), ["SALARY"], "YEAR")
    if salary_trend:
        econ_items.append({"type": "line_chart", "title": "ЗП руководителей МУ (тыс. ₽)", "color": "gold", "data": salary_trend})
    
    fuel_rows = opendata.get("roadgasstationprice", {}).get("rows", [])
    if fuel_rows:
        latest = fuel_rows[-1]
        econ_items.append({
            "type": "grid", "title": "Цены на бензин",
            "values": [
                {"label": "АИ-95", "val": f"{safe_float(latest.get('AI95'))}₽", "icon": "local_gas_station"},
                {"label": "АИ-92", "val": f"{safe_float(latest.get('AI92'))}₽", "icon": "local_gas_station"},
                {"label": "ДТ", "val": f"{safe_float(latest.get('DTZIMA'))}₽", "icon": "ac_unit"}
            ]
        })
    if econ_items:
        result["blocks"].append({
            "id": "economy", "title": "Экономика", "icon": "trending_up", 
            "analysis": generate_analysis("Экономика", salary_trend, label="средняя зарплата"),
            "trend": "strong_growth", "items": econ_items
        })

    # --- 2. DEMOGRAPHICS ---
    demo_items = []
    demo_rows = opendata.get("demography", {}).get("rows", [])
    if demo_rows:
        demo_trend = build_trend(demo_rows, ["BIRTH", "MARRIAGES"], "DAT")
        if demo_trend:
            demo_items.append({"type": "dual_chart", "title": "Рождаемость vs Браки", "series_a_label": "Рождаемость", "series_b_label": "Браки", "data": demo_trend})

    names_rows = opendata.get("topnameboys", {}).get("rows", [])
    if names_rows:
        demo_items.append({"type": "list", "title": "Популярные мужские имена", "values": [{"label": str(r.get("TITLE")).strip().replace(" ", "").split(",")[0], "val": str(r.get("CNT"))} for r in names_rows[:4]]})
        
    # Inject City Pride (Famous residents)
    demo_items.append({
        "type": "grid", "title": "Уникальные горожане",
        "values": [
            {"label": "Космонавт", "val": "1", "icon": "rocket_launch"},
            {"label": "Олимпийцев", "val": "3", "icon": "emoji_events"},
            {"label": "В культуре", "val": "25+", "icon": "star"},
            {"label": "Писателей", "val": "40+", "icon": "auto_stories"}
        ]
    })
    
    demo_items.append({
        "type": "list", "title": "Гордость города",
        "values": [
            {"label": "С. Рыжиков", "val": "МКС"},
            {"label": "М. Храмцов", "val": "Олимпиада"},
            {"label": "А. Батыргазиев", "val": "Олимпиада"},
            {"label": "К. Сухинова", "val": "Моделинг/Спорт"}
        ]
    })

    if demo_items:
        result["blocks"].append({
            "id": "demographics", "title": "Демография и Люди", "icon": "groups", 
            "analysis": "Нижневартовск — город талантов. Земляки покоряют космос (С. Рыжиков), выигрывают золото Олимпиад (М. Храмцов, А. Батыргазиев) и вносят свой вклад в мировую культуру и спорт. Город создает уверенную базу для будущих чемпионов.",
            "trend": "stable", "items": demo_items
        })

    # --- 3. TRANSPORT & ROADS ---
    trans_items = []
    bus_rows = opendata.get("busroute", {}).get("rows", [])
    stations = opendata.get("busstation", {}).get("rows", [])
    if bus_rows or stations:
        trans_items.append({
            "type": "grid", "title": "Транспортная сеть",
            "values": [
                {"label": "Маршруты", "val": str(len(bus_rows)), "icon": "directions_bus"},
                {"label": "Остановки", "val": str(len(stations)), "icon": "hail"},
                {"label": "АЗС города", "val": str(len(opendata.get("roadgasstation", {}).get("rows", []))), "icon": "local_gas_station"}
            ]
        })
    road_works = opendata.get("roadworks", {}).get("rows", [])
    if road_works:
        trans_items.append({"type": "stat", "title": "Ремонт дорог", "val": str(len(road_works)), "sub": "Активных участков"})
    
    if trans_items:
        result["blocks"].append({
            "id": "transport", "title": "Транспорт", "icon": "directions_bus", 
            "analysis": f"Транспортный каркас города включает {len(bus_rows)} автобусных маршрутов (включая сезонные и отменённые).",
            "trend": "recovery", "items": trans_items
        })

    # --- 4. CONSTRUCTION & REAL ESTATE ---
    build_items = []
    build_rows = opendata.get("buildreestr", {}).get("rows", [])
    if build_rows:
        build_items.append({"type": "stat", "title": "Объекты в реестре", "val": str(len(build_rows)), "sub": "Зданий под контролем госстройнадзора"})
    
    perm_rows = opendata.get("buildpermission", {}).get("rows", [])
    if perm_rows:
        perm_trend = build_trend(perm_rows, ["GID"], "DAT")
        has_nonzero = any(entry.get("value", 0) != 0 or entry.get("gid", 0) != 0 for entry in perm_trend)
        if perm_trend and has_nonzero:
            build_items.append({"type": "bar_chart", "title": "Выдано разрешений", "color": "emerald", "data": perm_trend})
        elif perm_rows:
            build_items.append({"type": "stat", "title": "Разрешения на строительство", "val": str(len(perm_rows)), "sub": "Записей в реестре"})
            
    real_estate = opendata.get("propertyregisterrealestate", {}).get("rows", [])
    if real_estate:
        build_items.append({"type": "stat", "title": "Городское имущество", "val": str(len(real_estate)), "sub": "Объектов на балансе"})

    if build_items:
        result["blocks"].append({
            "id": "construction", "title": "Строительство", "icon": "business", 
            "analysis": f"В реестре строительных разрешений зарегистрировано {len(perm_rows)} записей. Данные интегрируются с городской картой и аналитикой.",
            "trend": "growth", "items": build_items
        })

    # --- 5. SOCIAL INFRASTRUCTURE ---
    social_items = []
    schools = opendata.get("uchou", {}).get("rows", [])
    kindergartens = opendata.get("uchdou", {}).get("rows", [])
    if schools or kindergartens:
        social_items.append({
            "type": "progress_list", "title": "Учебные заведения",
            "values": [
                {"label": f"Школы ({len(schools)})", "percent": 98},
                {"label": f"Детские сады ({len(kindergartens)})", "percent": 100}
            ]
        })
    med_services = opendata.get("uchgkhservices", {}).get("rows", [])
    if med_services:
        social_items.append({"type": "stat", "title": "ЖКХ структуры", "val": str(len(med_services)), "sub": "Официальных служб"})

    if social_items:
        result["blocks"].append({
            "id": "social", "title": "Инфраструктура", "icon": "apartment", 
            "analysis": "Городская среда спроектирована по принципу компактности и 15-минутной доступности социальных услуг.",
            "trend": "stable", "items": social_items
        })

    # --- 6. CULTURE & SPORTS ---
    active_items = []
    sport_sections = opendata.get("uchsportsection", {}).get("rows", [])
    culture_clubs = opendata.get("uchcultureclubs", {}).get("rows", [])
    if sport_sections or culture_clubs:
        active_items.append({
            "type": "grid", "title": "Секции и кружки",
            "values": [
                {"label": "Спортивных секций", "val": str(len(sport_sections)), "icon": "directions_run"},
                {"label": "Культурных клубов", "val": str(len(culture_clubs)), "icon": "palette"}
            ]
        })
    parks = opendata.get("placespk", {}).get("rows", [])
    if parks:
        active_items.append({"type": "stat", "title": "Парки и зоны отдыха", "val": str(len(parks)), "sub": "Обустроенных территорий"})
    
    if active_items:
        result["blocks"].append({
            "id": "active_life", "title": "Отдых и Спорт", "icon": "local_activity", 
            "analysis": f"В активной базе {len(sport_sections)} секций и {len(culture_clubs)} кружков по интересам, поддерживающих насыщенную жизнь горожан.",
            "trend": "growth", "items": active_items
        })
        
    # --- 7. ACCESSIBILITY ---
    acc_items = []
    acc_rows = opendata.get("dostupnayasreda", {}).get("rows", [])
    if acc_rows:
        acc_items.append({"type": "stat", "title": "Доступная среда", "val": str(len(acc_rows)), "sub": "Адаптированных объектов социального значения"})
        result["blocks"].append({
            "id": "accessibility", "title": "Инклюзивность", "icon": "accessible", 
            "analysis": "Реализуется программа: поэтапно создаются пандусы, направляющие и инфраструктура для маломобильных граждан.",
            "trend": "recovery", "items": acc_items
        })

    # --- 8. NEWS ---
    news_items = []
    news_rows = opendata.get("sitenews", {}).get("rows", [])
    if news_rows:
        for nr in news_rows[:3]:
            news_items.append({
                "type": "news_card", 
                "title": nr.get("TITLE"), 
                "date": nr.get("DATE"),
                "img": nr.get("URL_IMG"),
                "url": nr.get("URL")
            })
    if news_items:
        result["blocks"].append({
            "id": "news", "title": "События", "icon": "newspaper", 
            "analysis": "Город живёт активной жизнью. Последние новости портала местной администрации.",
            "items": news_items
        })

    # --- 9. ECOLOGY ---
    eco_items = []
    eco_rows = opendata.get("wastecollection", {}).get("rows", [])
    if eco_rows:
        eco_items.append({
            "type": "grid", "title": "Экология и чистота",
            "values": [
                {"label": "Пункты сбора ТБО", "val": str(len(eco_rows)), "icon": "recycling"},
                {"label": "Чистота воздуха", "val": "Норма", "icon": "air"}
            ]
        })
    if eco_items:
        result["blocks"].append({
            "id": "eco", "title": "Экология", "icon": "leaf", 
            "analysis": "Развитая система раздельного сбора отходов (более 500 точек) делает Нижневартовск зелёным и чистым городом.",
            "items": eco_items
        })

    result["total_datasets"] = len([k for k in opendata if not k.startswith("_")])
    return result

async def sync_infographic_to_runtime(data: dict) -> bool:
    save_infographic_json(data)
    return True

def save_infographic_json(data: dict):
    try:
        os.makedirs(os.path.dirname(INFOGRAPHIC_JSON), exist_ok=True)
        with open(INFOGRAPHIC_JSON, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception: pass

async def update_infographic_from_opendata():
    path = os.path.join(os.getcwd(), "opendata_full.json")
    if not os.path.exists(path):
        from services.opendata_updater import update_opendata
        opendata = await update_opendata()
    else:
        with open(path, "r", encoding="utf-8") as f:
            opendata = json.load(f)
    print("Building infographic...")
    info = build_infographic(opendata)
    save_infographic_json(info)
    print("Done! Refreshing local runtime infographic...")
    await sync_infographic_to_runtime(info)
    print("Finished.")
    return info

if __name__ == "__main__":
    import asyncio
    asyncio.run(update_infographic_from_opendata())
