"""Check Firebase complaints data via CF Worker proxy"""
import urllib.request, json

FB = 'https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase'
try:
    req = urllib.request.Request(FB + '/complaints.json?shallow=true',
        headers={'User-Agent': 'Mozilla/5.0'})
    r = urllib.request.urlopen(req, timeout=10)
    data = json.loads(r.read())
    if data:
        count = len(data)
        print(f"Firebase complaints: {count} entries")
    else:
        print("Firebase complaints: EMPTY or null")
        print("Raw:", data)
except Exception as e:
    print(f"Error: {e}")
    # Try without shallow
    try:
        req2 = urllib.request.Request(FB + '/complaints.json',
            headers={'User-Agent': 'Mozilla/5.0'})
        r2 = urllib.request.urlopen(req2, timeout=10)
        raw = r2.read()
        print(f"Full response: {len(raw)} bytes")
        data = json.loads(raw)
        if data:
            print(f"Got {len(data)} entries")
            for k in list(data.keys())[:2]:
                print(f"  {k}: {json.dumps(data[k], ensure_ascii=False)[:150]}")
        else:
            print("Data is null/empty")
    except Exception as e2:
        print(f"Error 2: {e2}")
