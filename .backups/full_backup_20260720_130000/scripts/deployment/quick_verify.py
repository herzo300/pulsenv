"""Quick verify of server after rebuild."""
import os, sys, time, json, urllib.parse
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

time.sleep(5)

# Health
_, o, _ = ssh.exec_command("curl -s http://localhost/health", timeout=10)
o.channel.recv_exit_status()
print("Health:", o.read().decode().strip())

# Cache inside container
_, o, _ = ssh.exec_command(
    'docker exec soobshio_backend python3 -c "import json; d=json.load(open(\\"/app/data/geocode_cache.json\\", encoding=\\"utf-8\\")); print(f\\"Cache: {len(d)} entries\\")"',
    timeout=10
)
o.channel.recv_exit_status()
print(o.read().decode().strip())

# Test UK companies
for uk_name in ['ООО "ПРЭТ №3"', 'ООО "УК "Диалог"', 'АО "ЖТ №1"']:
    encoded = urllib.parse.quote(uk_name)
    _, o, _ = ssh.exec_command(
        f'curl -s "http://localhost/api/uk/{encoded}/houses_coordinates"',
        timeout=120
    )
    o.channel.recv_exit_status()
    raw = o.read().decode("utf-8", errors="replace").strip()
    try:
        data = json.loads(raw)
        total = data.get("total", 0)
        print(f"{uk_name}: {total} houses with coordinates")
    except:
        print(f"{uk_name}: {raw[:100]}")

ssh.close()
