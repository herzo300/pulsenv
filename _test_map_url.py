import os
from dotenv import load_dotenv
load_dotenv()

CF_WORKER = "https://anthropic-proxy.uiredepositionherzo.workers.dev"
url = os.getenv("WEBAPP_URL", "")
print(f"WEBAPP_URL env: '{url}'")
if not url:
    tunnel = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tunnel_url.txt")
    if os.path.exists(tunnel):
        with open(tunnel) as f:
            url = f.read().strip()
        print(f"tunnel_url.txt: {url}")
    else:
        url = CF_WORKER
        print(f"Using CF_WORKER: {url}")

import time
print(f"Map URL: {url}/map?v={int(time.time())}")
