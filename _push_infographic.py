"""Push infographic_data.json to Firebase RTDB via CF Worker proxy"""
import json, httpx, time

CF = "https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase"

with open("infographic_data.json", "r", encoding="utf-8") as f:
    data = json.load(f)

# Push key by key to avoid large payload issues
client = httpx.Client(timeout=15)
ok, fail = 0, 0
for key, val in data.items():
    try:
        r = client.put(f"{CF}/opendata_infographic/{key}.json", json=val)
        if r.status_code == 200:
            ok += 1
        else:
            fail += 1
            print(f"  FAIL {key}: {r.status_code}")
        time.sleep(0.2)
    except Exception as e:
        fail += 1
        print(f"  ERR {key}: {e}")
        time.sleep(1)

print(f"Done: {ok} ok, {fail} fail")
client.close()
