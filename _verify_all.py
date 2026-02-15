"""Final verification of map + bot"""
import os, urllib.request, json

print("=== Verification ===\n")

# 1. tunnel_url.txt deleted
print(f"1. tunnel_url.txt exists: {os.path.exists('tunnel_url.txt')} (should be False)")

# 2. Bot webapp URL
CF_WORKER = "https://anthropic-proxy.uiredepositionherzo.workers.dev"
def _get_webapp_url():
    url = os.getenv("WEBAPP_URL", "")
    if url: return url
    tunnel = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tunnel_url.txt")
    if os.path.exists(tunnel):
        with open(tunnel, "r") as f: return f.read().strip()
    return CF_WORKER
url = _get_webapp_url()
print(f"2. WebApp URL: {url}")
print(f"   Map opens at: {url}/map")

# 3. Map endpoint
try:
    req = urllib.request.Request(url + '/map', headers={'User-Agent': 'Mozilla/5.0'})
    r = urllib.request.urlopen(req, timeout=10)
    body = r.read().decode('utf-8', errors='replace')
    has_filters = 'filter-bar' in body
    has_markers = 'mkIcon' in body or 'CAT_COLORS' in body
    has_popups = 'buildPopup' in body
    has_firebase = 'loadFromFirebase' in body
    has_status = 'STATUS_LABEL' in body
    print(f"3. Map endpoint: {r.status} OK, {len(body)} bytes")
    print(f"   Filters: {'✓' if has_filters else '✗'}")
    print(f"   Markers: {'✓' if has_markers else '✗'}")
    print(f"   Popups: {'✓' if has_popups else '✗'}")
    print(f"   Firebase: {'✓' if has_firebase else '✗'}")
    print(f"   Status filter: {'✓' if has_status else '✗'}")
except Exception as e:
    print(f"3. Map endpoint error: {e}")

# 4. Firebase data
try:
    req = urllib.request.Request(url + '/firebase/complaints.json?shallow=true',
        headers={'User-Agent': 'Mozilla/5.0'})
    r = urllib.request.urlopen(req, timeout=10)
    data = json.loads(r.read())
    count = len(data) if data else 0
    print(f"4. Firebase complaints: {count} entries")
except Exception as e:
    print(f"4. Firebase error: {e}")

# 5. Info endpoint
try:
    req = urllib.request.Request(url + '/info', headers={'User-Agent': 'Mozilla/5.0'})
    r = urllib.request.urlopen(req, timeout=10)
    print(f"5. Info endpoint: {r.status} OK, {len(r.read())} bytes")
except Exception as e:
    print(f"5. Info endpoint error: {e}")

print("\n=== Done ===")
