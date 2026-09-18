"""Deploy geo_service.py fix and verify endpoint."""
import os, sys, time
import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname="45.153.68.59", username="root",
            password=os.getenv("SSH_PASSWORD", "").strip(),
            timeout=15, look_for_keys=False, allow_agent=False)

# Upload fixed geo_service.py
sftp = ssh.open_sftp()
local_geo = r"C:\Soobshio_project\services\business\geo_service.py"
remote_geo = "/opt/soobshio/services/business/geo_service.py"
print(f"Uploading geo_service.py...")
sftp.put(local_geo, remote_geo)
print(f"Uploaded ({os.path.getsize(local_geo):,} bytes)")
sftp.close()

# Restart backend to pick up the fix
print("Restarting backend...")
_, o, _ = ssh.exec_command("cd /opt/soobshio && docker compose restart backend 2>&1", timeout=60)
o.channel.recv_exit_status()
print(o.read().decode("utf-8", errors="replace").strip())

# Wait for startup
print("Waiting 10s for startup...")
time.sleep(10)

# Verify health
_, o, _ = ssh.exec_command("curl -s http://localhost/health", timeout=10)
o.channel.recv_exit_status()
print("Health:", o.read().decode("utf-8", errors="replace").strip())

# Verify cache size inside container
_, o, _ = ssh.exec_command(
    'docker exec soobshio_backend python3 -c "'
    'import json; d=json.load(open(\"/app/data/geocode_cache.json\", encoding=\"utf-8\")); '
    'print(f\"Cache entries: {len(d)}\")'
    '" 2>&1', timeout=10)
o.channel.recv_exit_status()
print(o.read().decode("utf-8", errors="replace").strip())

# Test houses_coordinates endpoint with URL-encoded UK name
import urllib.parse
uk_name = 'ООО "ПРЭТ №3"'
encoded = urllib.parse.quote(uk_name)
print(f"\nTesting houses_coordinates for: {uk_name}")
_, o, _ = ssh.exec_command(f'curl -s "http://localhost/api/uk/{encoded}/houses_coordinates" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\\"Total houses: {{d.get(\'total\', 0)}}\\"); houses=d.get(\'houses\',[]); [print(f\\"  {{h[\'address\']}}: {{h[\'lat\']}}, {{h[\'lon\']}}\\"  ) for h in houses[:5]]" 2>&1', timeout=120)
o.channel.recv_exit_status()
print(o.read().decode("utf-8", errors="replace").strip())

ssh.close()
print("\nDone!")
