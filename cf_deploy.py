"""Deploy CF Worker — Connection: close, no keep-alive, fresh socket each try."""
import json, os, time, http.client, ssl, socket

# Token
cfg = os.path.join(os.environ.get("APPDATA",""),
    "xdg.config",".wrangler","config","default.toml")
token = None
for line in open(cfg):
    if line.startswith("oauth_token"):
        token = line.split("=",1)[1].strip().strip('"')
        break
print(f"Token: {token[:15]}...")

AID = "b55123fb7c25f3c5f38a1dcab5a36fa8"
SN = "anthropic-proxy"
API_PATH = f"/client/v4/accounts/{AID}/workers/scripts/{SN}"

with open("cloudflare-worker/worker.js","r",encoding="utf-8") as f:
    code = f.read()
print(f"Code: {len(code)} chars")

B = "----PULS_GORODA_DEPLOY"
meta = json.dumps({"main_module":"worker.js",
    "compatibility_date":"2024-01-01"})
parts = []
parts.append("--"+B)
parts.append('Content-Disposition: form-data; name="metadata"')
parts.append("Content-Type: application/json")
parts.append("")
parts.append(meta)
parts.append("--"+B)
parts.append('Content-Disposition: form-data; name="worker.js"; filename="worker.js"')
parts.append("Content-Type: application/javascript+module")
parts.append("")
parts.append(code)
parts.append("--"+B+"--")
body = "\r\n".join(parts).encode("utf-8")
print(f"Body: {len(body)} bytes")

ctx = ssl.create_default_context()
HOST = "api.cloudflare.com"

for attempt in range(5):
    print(f"\n--- Attempt {attempt+1} ---")
    conn = None
    try:
        # Fresh socket, no reuse
        sock = socket.create_connection((HOST, 443), timeout=30)
        ssock = ctx.wrap_socket(sock, server_hostname=HOST)
        conn = http.client.HTTPSConnection(HOST, context=ctx)
        conn.sock = ssock
        conn.request("PUT", API_PATH, body=body, headers={
            "Authorization": "Bearer " + token,
            "Content-Type": "multipart/form-data; boundary=" + B,
            "Content-Length": str(len(body)),
            "Connection": "close",
            "User-Agent": "PulsGoroda-Deploy/1.0",
        })
        resp = conn.getresponse()
        data = resp.read().decode("utf-8","replace")
        print(f"HTTP {resp.status}")
        if resp.status == 200:
            r = json.loads(data)
            if r.get("success"):
                mid = r["result"].get("modified_on","?")
                print(f"DEPLOYED! modified={mid}")
            else:
                print(f"Errors: {r.get('errors')}")
            break
        else:
            print(data[:400])
            break
    except Exception as e:
        print(f"  Error: {e}")
    finally:
        if conn:
            try: conn.close()
            except: pass
    time.sleep(3)
