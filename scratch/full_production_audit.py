import os, sys, time, json, httpx, paramiko, dotenv

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

dotenv.load_dotenv(r"C:\Soobshio_project\.env")
base = "https://45-153-68-59.sslip.io"
client = httpx.Client(verify=False, trust_env=False, timeout=20.0)

results = {}

endpoints = [
    ("GET", "/health", "Health Check"),
    ("GET", "/categories", "Categories List"),
    ("GET", "/api/reports?limit=5", "Reports Feed (5 items)"),
    ("GET", "/api/reports?limit=1&category=Животные", "Reports: Animals filter"),
    ("GET", "/api/map/reports", "Map Data"),
    ("GET", "/api/weather-alerts/latest", "Weather Alerts"),
    ("GET", "/api/pulse/stats", "Pulse Stats"),
    ("GET", "/api/reports/lost-found/tts?text=Тест+озвучки+находок", "Lost&Found Female TTS"),
    ("GET", "/api/reports/tts?text=Тест+озвучки", "General TTS"),
    ("GET", "/api/rag/ask?question=Когда+будет+ремонт+дороги", "RAG AI Ask"),
    ("GET", "/api/transport/stops?lat=60.9344&lng=76.5531", "Transport Stops"),
    ("GET", "/api/fuel/prices", "Fuel Prices"),
    ("GET", "/api/gamification/leaderboard", "Gamification Leaderboard"),
    ("GET", "/api/daily-fun", "Daily Fun"),
    ("GET", "/profile/settings", "Profile Settings"),
    ("GET", "/api/jkh/tariffs", "JKH Tariffs"),
    ("GET", "/api/watchdog/status", "Watchdog Status"),
]

print(f"{'#':>2} {'Status':>6}  {'Time':>7}  {'Bytes':>8}  Endpoint")
print("-" * 75)

for i, (method, ep, label) in enumerate(endpoints, 1):
    url = f"{base}{ep}"
    t0 = time.time()
    try:
        if method == "GET":
            r = client.get(url)
        else:
            r = client.post(url)
        dt = (time.time() - t0) * 1000
        status = r.status_code
        size = len(r.content)
        mark = "✅" if status in (200, 201) else ("⚠️" if status in (401, 403, 404, 405, 422) else "❌")
        print(f"{i:>2} [{status:>3}]  {dt:>6.0f}ms  {size:>7}b  {mark} {label}")
        results[label] = {"status": status, "time_ms": round(dt), "bytes": size}
    except Exception as e:
        print(f"{i:>2} [ERR]            {label} -> {e}")
        results[label] = {"status": "ERR", "error": str(e)}

# Database check via SSH
print("\n=== DATABASE CHECK ===")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"), timeout=10)

db_script = "from services.data_layer.database import SessionLocal; from services.data_layer.models import Report; db=SessionLocal(); t=db.query(Report).count(); p=db.query(Report).filter(Report.description.like('%Фото:%')).count(); print(f'Total: {t}, With_Photos: {p}'); db.close()"
channel = ssh.get_transport().open_session()
channel.settimeout(6)
channel.exec_command(f'docker exec soobshio_backend python -c "{db_script}"')
data = b""
while True:
    try:
        chunk = channel.recv(4096)
        if not chunk: break
        data += chunk
    except: break
print(data.decode('utf-8', 'replace'))

# Docker containers status
print("=== DOCKER CONTAINERS ===")
channel2 = ssh.get_transport().open_session()
channel2.settimeout(5)
channel2.exec_command("docker ps --format 'table {{.Names}}\t{{.Status}}'")
data2 = b""
while True:
    try:
        chunk = channel2.recv(4096)
        if not chunk: break
        data2 += chunk
    except: break
print(data2.decode('utf-8', 'replace'))

ssh.close()

ok = sum(1 for v in results.values() if isinstance(v.get("status"), int) and v["status"] in (200, 201))
warn = sum(1 for v in results.values() if isinstance(v.get("status"), int) and v["status"] in (401, 403, 404, 405, 422))
fail = sum(1 for v in results.values() if isinstance(v.get("status"), int) and v["status"] >= 500)
err = sum(1 for v in results.values() if v.get("status") == "ERR")

print(f"\n=== SUMMARY: {ok} OK / {warn} Expected-4xx / {fail} Server-Error / {err} Connection-Error ===")
