import sys
sys.stdout.reconfigure(encoding='utf-8')
import httpx

c = httpx.Client(verify=False, timeout=10)
base = "https://45-153-68-59.sslip.io"

for ep, label in [("/health", "Health"), ("/categories", "Categories"), ("/api/reports?limit=2", "Reports"), ("/api/pulse/stats", "Stats")]:
    r = c.get(f"{base}{ep}")
    print(f"[{r.status_code}] {label} - {len(r.content)} bytes")
