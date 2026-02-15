"""Test CF Worker endpoints"""
import httpx

CF = 'https://anthropic-proxy.uiredepositionherzo.workers.dev'

r = httpx.get(f'{CF}/map', timeout=15, follow_redirects=True)
print(f"GET /map: {r.status_code}, {len(r.text)} chars")
has_maplibre = 'maplibre' in r.text.lower()
has_pulse_bar = 'pulse-bar' in r.text or 'pulseCanvas' in r.text
print(f"  MapLibre GL: {has_maplibre}")

r2 = httpx.get(f'{CF}/info', timeout=15, follow_redirects=True)
print(f"GET /info: {r2.status_code}, {len(r2.text)} chars")
has_bgcanvas = 'bgCanvas' in r2.text
has_pulse = 'pulse-bar' in r2.text
has_no_react = 'react' not in r2.text.lower() or 'react@18' not in r2.text
print(f"  Animated BG canvas: {has_bgcanvas}")
print(f"  City Pulse bar: {has_pulse}")
print(f"  No React: {has_no_react}")

r3 = httpx.get(f'{CF}/firebase/complaints.json', timeout=10)
print(f"GET /firebase/complaints.json: {r3.status_code}")
if r3.status_code == 200:
    data = r3.json()
    print(f"  Complaints: {len(data) if data else 0}")

r4 = httpx.get(f'{CF}/firebase/opendata_infographic.json', timeout=10)
print(f"GET /firebase/opendata_infographic.json: {r4.status_code}")
if r4.status_code == 200:
    d = r4.json()
    print(f"  Has data: {bool(d)}, datasets: {d.get('datasets_total','?') if d else '?'}")
