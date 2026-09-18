"""Fetch fuel prices for Nizhnevartovsk from fuelprice.ru and russiabase.ru.
Output: public/fuel_stations_nv.json with lat/lng, brand, prices, updated_at.
"""
import ssl
import urllib.request
import re
import json
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / 'public' / 'fuel_stations_nv.json'

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
UA = 'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 Chrome/126.0 Safari/537.36'

# Coordinates of known gas station brands in NV (approximate, from Yandex Maps)
# Will be refined by geocoding if needed
KNOWN_STATIONS = {
    # Лукойл
    'АЗС №41': {'lat': 60.9530, 'lng': 76.5840, 'brand': 'ЛУКОЙЛ', 'address': 'ул. Мира, 1'},
    'АЗС №43': {'lat': 60.9420, 'lng': 76.4860, 'brand': 'ЛУКОЙЛ', 'address': 'ул. Северная, 1А (аэропорт)'},
    'АЗС №45': {'lat': 60.9320, 'lng': 76.5810, 'brand': 'ЛУКОЙЛ', 'address': 'ул. Чапаева'},
    # Газпромнефть
    'Газпромнефть': {'lat': 60.9390, 'lng': 76.5700, 'brand': 'Газпромнефть', 'address': 'ул. Мира'},
    # Роснефть / ТНК
    'Роснефть': {'lat': 60.9300, 'lng': 76.5530, 'brand': 'Роснефть', 'address': 'центр'},
    'ТНК': {'lat': 60.9400, 'lng': 76.5800, 'brand': 'ТНК', 'address': 'ул. Мира'},
    # Сургутнефтегаз
    'Сургутнефтегаз': {'lat': 60.9450, 'lng': 76.5600, 'brand': 'Сургутнефтегаз', 'address': 'ул. Ленина'},
    # ОКИС-С (локальная сеть)
    'ОКИС-С': {'lat': 60.9280, 'lng': 76.5570, 'brand': 'ОКИС-С', 'address': 'центр'},
    # Shell
    'Shell': {'lat': 60.9430, 'lng': 76.5900, 'brand': 'Shell', 'address': 'ул. Мира'},
}


def fetch_html(url, timeout=20):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept-Language': 'ru-RU,ru;q=0.9'})
        with urllib.request.urlopen(req, context=ctx, timeout=timeout) as r:
            return r.read().decode('utf-8', errors='replace')
    except Exception as e:
        print(f'  fetch err: {e}')
        return ''


def parse_fuelprice_ru():
    """Parse fuelprice.ru table — returns list of dicts."""
    print('=== Parsing fuelprice.ru ===')
    html = fetch_html('https://fuelprice.ru/t-nizhnevartovsk')
    if not html:
        return []
    tables = re.findall(r'<table[^>]*>(.*?)</table>', html, re.S)
    if not tables:
        return []
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', tables[0], re.S)

    stations = {}  # name -> {brand, prices: {fuel: price}, updated_at, address}
    for row in rows[1:]:  # skip header
        cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.S)
        cells = [re.sub(r'<[^>]+>', '', c).strip() for c in cells]
        if len(cells) < 5:
            continue
        name, brand, fuel, price_str, updated = cells[0], cells[1], cells[2], cells[3], cells[4]
        try:
            price = float(price_str.replace(',', '.'))
        except (ValueError, TypeError):
            continue
        # Normalize fuel name
        fuel_norm = fuel.lower().replace('аи-', 'АИ-').replace('аи', 'АИ-').replace('дт', 'ДТ').upper()
        if 'АИ' not in fuel_norm and 'ДТ' not in fuel_norm:
            fuel_norm = fuel
        # Detect brand from name or brand column
        detected_brand = brand.upper() if brand else 'НЕТ'
        if not detected_brand or detected_brand == 'НЕТ':
            for b in ['ЛУКОЙЛ', 'ГАЗПРОМНЕФТЬ', 'ГАЗПРОМ', 'РОСНЕФТЬ', 'ТНК', 'СУРГУТНЕФТЕГАЗ', 'SHELL', 'ОКИС']:
                if b in name.upper():
                    detected_brand = b
                    break
        # Group by station name
        if name not in stations:
            stations[name] = {
                'name': name,
                'brand': detected_brand,
                'prices': {},
                'updated_at': updated,
                'address': '',
            }
        stations[name]['prices'][fuel_norm] = price
        # Take latest updated_at
        try:
            current = datetime.strptime(stations[name]['updated_at'], '%Y-%m-%d')
            new = datetime.strptime(updated, '%Y-%m-%d')
            if new > current:
                stations[name]['updated_at'] = updated
        except ValueError:
            pass

    print(f'  Parsed {len(stations)} stations')
    return list(stations.values())


def parse_russiabase_ru():
    """Parse russiabase.ru — fallback for coords."""
    print('\n=== Parsing russiabase.ru ===')
    html = fetch_html('https://russiabase.ru/prices?city=154203')
    # Look for embedded JSON with station coords
    json_blocks = re.findall(r'\{[^{}]*"coords"[^{}]*\}', html)
    print(f'  Found {len(json_blocks)} coord blocks')
    return html


def assign_coordinates(stations):
    """Try to assign lat/lng based on station name and brand."""
    print('\n=== Assigning coordinates ===')
    for s in stations:
        coords = None
        # Try exact match
        for key, info in KNOWN_STATIONS.items():
            if key.lower() in s['name'].lower():
                coords = info
                break
        # Try brand match (center of city as fallback)
        if coords is None:
            brand = s.get('brand', '').upper()
            for key, info in KNOWN_STATIONS.items():
                if info['brand'].upper() == brand:
                    coords = info
                    break
        if coords:
            s['lat'] = coords['lat']
            s['lng'] = coords['lng']
            if not s.get('address'):
                s['address'] = coords.get('address', '')
        else:
            # Default to city center with small offset
            import random
            random.seed(hash(s['name']) & 0xFFFFFFFF)
            s['lat'] = 60.9344 + (random.random() - 0.5) * 0.04
            s['lng'] = 76.5531 + (random.random() - 0.5) * 0.06
            s['address'] = s.get('address') or 'Нижневартовск'
    return stations


def main():
    stations = parse_fuelprice_ru()
    stations = assign_coordinates(stations)

    # Compute aggregates (min price per fuel type)
    print('\n=== Stats ===')
    fuels = set()
    for s in stations:
        fuels.update(s['prices'].keys())
    print(f'Fuel types: {sorted(fuels)}')
    for f in sorted(fuels):
        prices = [s['prices'][f] for s in stations if f in s['prices']]
        if prices:
            print(f'  {f}: min={min(prices):.2f} max={max(prices):.2f} avg={sum(prices)/len(prices):.2f} ({len(prices)} stations)')

    # Add metadata
    output = {
        'city': 'nizhnevartovsk',
        'city_name': 'Нижневартовск',
        'generated_at': datetime.now(timezone(timedelta(hours=5))).isoformat(),
        'source': 'fuelprice.ru',
        'total_stations': len(stations),
        'stations': stations,
        'avg_prices': {
            f: round(sum(s['prices'][f] for s in stations if f in s['prices']) /
                     max(1, len([s for s in stations if f in s['prices']])), 2)
            for f in fuels
        },
        'min_prices': {
            f: min(s['prices'][f] for s in stations if f in s['prices'])
            for f in fuels
            if any(f in s['prices'] for s in stations)
        },
    }
    OUT.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'\n✅ Saved {len(stations)} stations to {OUT}')

    # Show sample
    print('\n=== Sample stations ===')
    for s in stations[:5]:
        print(f'  {s["name"]} ({s["brand"]}) @ [{s["lat"]:.4f}, {s["lng"]:.4f}]')
        for f, p in s['prices'].items():
            print(f'    {f}: {p:.2f} ₽ (обновлено {s["updated_at"]})')


if __name__ == '__main__':
    main()
