"""
Build unified cameras JSON for both cities (NV + NSK).
NV: 130 cameras from public/cameras_nv.json (already health-checked, with online field)
NSK: discovered streams from tv.novo-sibirsk.ru (roads + monuments + broadcast)
Output: public/cameras_all.json with city field, public/cameras_nsk.json
"""
import json
import ssl
import urllib.request
import concurrent.futures as cf
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
NV_SRC = ROOT / 'public' / 'cameras_nv.json'
NSK_OUT = ROOT / 'public' / 'cameras_nsk.json'
ALL_OUT = ROOT / 'public' / 'cameras_all.json'

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
UA = 'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 Chrome/126.0 Safari/537.36'

# ============================================================
# NSK cameras — known working URLs from discovery
# ============================================================
# Coordinates for NSK landmarks (from public sources / Yandex Maps)
NSK_CAMERAS = [
    # Дорожные камеры (мэрия tv.novo-sibirsk.ru/roads/)
    {"slug": "pl_pimenova",     "name": "Пименовка (перекрёсток)",     "lat": 55.0407, "lng": 82.9473, "provider": "novo-sibirsk.ru", "district": "Железнодорожный"},
    {"slug": "LDS",              "name": "ЛДС Сибирь (Белова)",         "lat": 55.0410, "lng": 82.9340, "provider": "novo-sibirsk.ru", "district": "Центральный"},
    {"slug": "Lenina_Kras",      "name": "Ленина — Красный проспект",   "lat": 55.0303, "lng": 82.9244, "provider": "novo-sibirsk.ru", "district": "Центральный"},
    {"slug": "Sovet_Chas",       "name": "Советское шоссе — Часовая",  "lat": 55.0624, "lng": 82.9220, "provider": "novo-sibirsk.ru", "district": "Советский"},
    {"slug": "pl_Lunencev",      "name": "Площадь Лунинцев",            "lat": 55.0796, "lng": 82.9356, "provider": "novo-sibirsk.ru", "district": "Заельцовский"},
    {"slug": "pl_Truda",         "name": "Площадь Труда",               "lat": 55.0440, "lng": 82.9250, "provider": "novo-sibirsk.ru", "district": "Центральный"},
    {"slug": "Lenin_Ordze",      "name": "Ленина — Орджоникидзе",       "lat": 55.0290, "lng": 82.9230, "provider": "novo-sibirsk.ru", "district": "Центральный"},
    {"slug": "Krilov_Krasny",    "name": "Крылова — Красный проспект", "lat": 55.0336, "lng": 82.9230, "provider": "novo-sibirsk.ru", "district": "Центральный"},
    {"slug": "Gogola_Krasny",    "name": "Гоголя — Красный проспект",   "lat": 55.0348, "lng": 82.9210, "provider": "novo-sibirsk.ru", "district": "Центральный"},
    # Площади и монументы
    {"slug": "Pervomay_GerRev_NTK", "name": "Первомайский сквер (Фонтан)", "lat": 55.0358, "lng": 82.9253, "provider": "novo-sibirsk.ru", "district": "Центральный"},
    {"slug": "monument_1",        "name": "Монумент Славы (вид 1)",     "lat": 54.9833, "lng": 82.8833, "provider": "novo-sibirsk.ru", "district": "Октябрьский"},
    {"slug": "monument_2",        "name": "Монумент Славы (вид 2)",     "lat": 54.9835, "lng": 82.8838, "provider": "novo-sibirsk.ru", "district": "Октябрьский"},
    {"slug": "monument_3",        "name": "Монумент Славы (вид 3)",     "lat": 54.9837, "lng": 82.8843, "provider": "novo-sibirsk.ru", "district": "Октябрьский"},
    {"slug": "monument_4",        "name": "Монумент Славы (вид 4)",     "lat": 54.9839, "lng": 82.8848, "provider": "novo-sibirsk.ru", "district": "Октябрьский"},
    {"slug": "monument_5",        "name": "Монумент Славы (вид 5)",     "lat": 54.9841, "lng": 82.8853, "provider": "novo-sibirsk.ru", "district": "Октябрьский"},
    # Альтернативный сервер
    {"slug": "PlPimenova",        "name": "Пименовка (alt server)",     "lat": 55.0407, "lng": 82.9473, "provider": "novo-sibirsk.ru", "district": "Железнодорожный"},
]


def build_url(slug, server='wowza-2.novo-sibirsk.ru'):
    """Build playlist URL for given slug.
    Most road cameras are under /live_km/, monuments under /live/."""
    if slug.startswith('monument_'):
        return f'https://{server}/live/{slug}.stream/playlist.m3u8'
    if slug == 'Pervomay_GerRev_NTK':
        return f'https://{server}/live/{slug}.stream/playlist.m3u8'
    if slug == 'PlPimenova':
        return f'https://wowza-1.novo-sibirsk.ru/live/{slug}.stream/playlist.m3u8'
    return f'https://{server}/live_km/{slug}.stream/playlist.m3u8'


def check_url(url, timeout=6):
    """Return (status_code_or_None, latency_ms)."""
    t0 = time.time()
    try:
        req = urllib.request.Request(url, method='HEAD', headers={'User-Agent': UA})
        with urllib.request.urlopen(req, context=ctx, timeout=timeout) as r:
            return r.status, int((time.time() - t0) * 1000)
    except urllib.error.HTTPError as e:
        return e.code, int((time.time() - t0) * 1000)
    except Exception:
        # try GET range
        try:
            req = urllib.request.Request(url, headers={'User-Agent': UA, 'Range': 'bytes=0-1023'})
            with urllib.request.urlopen(req, context=ctx, timeout=timeout) as r:
                return r.status, int((time.time() - t0) * 1000)
        except Exception:
            return None, int((time.time() - t0) * 1000)


# Build NSK entries with stream URLs
nsk_cameras = []
for c in NSK_CAMERAS:
    url = build_url(c['slug'])
    entry = {
        'n': c['name'],
        'name': c['name'],
        'lat': c['lat'],
        'lng': c['lng'],
        'street': c['name'],
        'district': c['district'],
        'district_id': c['district'].lower(),
        'provider': c['provider'],
        'view_type': 'street' if not c['slug'].startswith('monument') else 'landmark',
        'view_angle': '90',
        'is_secret': False,
        'secret': False,
        'streamable': True,
        's': url,
        'stream_url': url,
        'city': 'novosibirsk',
        'city_name': 'Новосибирск',
    }
    nsk_cameras.append(entry)

# Health-check NSK cameras
print(f'=== Health-check {len(nsk_cameras)} NSK cameras ===')
online_count = 0
with cf.ThreadPoolExecutor(max_workers=10) as ex:
    futs = {ex.submit(check_url, c['stream_url']): i for i, c in enumerate(nsk_cameras)}
    for fut in cf.as_completed(futs):
        i = futs[fut]
        status, ms = fut.result()
        nsk_cameras[i]['online'] = (status in (200, 206))
        nsk_cameras[i]['status_code'] = status
        nsk_cameras[i]['latency_ms'] = ms
        nsk_cameras[i]['last_checked'] = int(time.time())
        if nsk_cameras[i]['online']:
            online_count += 1
        tag = '✅' if nsk_cameras[i]['online'] else '❌'
        print(f'  {tag} {nsk_cameras[i]["name"]:42} | {status} | {ms}ms')

print(f'\nNSK online: {online_count}/{len(nsk_cameras)}')

# Save NSK JSON
NSK_OUT.write_text(json.dumps(nsk_cameras, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'✅ Saved: {NSK_OUT}')

# ============================================================
# Combine NV + NSK
# ============================================================
nv_cameras = json.load(open(NV_SRC, encoding='utf-8'))
# Mark all NV cameras with city
for c in nv_cameras:
    c.setdefault('city', 'nizhnevartovsk')
    c.setdefault('city_name', 'Нижневартовск')

combined = nv_cameras + nsk_cameras
ALL_OUT.write_text(json.dumps(combined, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'\n=== Combined: {len(combined)} cameras ({len(nv_cameras)} NV + {len(nsk_cameras)} NSK) ===')
print(f'✅ Saved: {ALL_OUT}')

# Stats
nv_online = sum(1 for c in nv_cameras if c.get('online'))
nsk_online = sum(1 for c in nsk_cameras if c.get('online'))
print(f'\nFinal stats:')
print(f'  NV  online: {nv_online}/{len(nv_cameras)} ({nv_online*100//len(nv_cameras) if nv_cameras else 0}%)')
print(f'  NSK online: {nsk_online}/{len(nsk_cameras)} ({nsk_online*100//len(nsk_cameras) if nsk_cameras else 0}%)')
print(f'  Total online: {nv_online + nsk_online}/{len(combined)}')
