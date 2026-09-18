"""Check raw file on server vs local."""
import os, sys, json
import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv(r"C:\Soobshio_project\.env")

# Local count
local_cache = json.load(open(r"C:\Soobshio_project\data\geocode_cache.json", encoding="utf-8"))
print(f"LOCAL cache entries: {len(local_cache)}")
print(f"LOCAL file size: {os.path.getsize(r'C:\Soobshio_project\data\geocode_cache.json')} bytes")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname="45.153.68.59", username="root",
            password=os.getenv("SSH_PASSWORD", "").strip(),
            timeout=15, look_for_keys=False, allow_agent=False)

# Check raw file size and entry count on server
cmds = [
    "ls -la /opt/soobshio/data/geocode_cache.json",
    "wc -c /opt/soobshio/data/geocode_cache.json",
    "python3 -c \"import json; d=json.load(open('/opt/soobshio/data/geocode_cache.json', encoding='utf-8')); print(f'SERVER entries: {len(d)}')\"",
    # Check inside container too
    "docker exec soobshio_backend wc -c /app/data/geocode_cache.json",
    "docker exec soobshio_backend python3 -c \"import json; d=json.load(open('/app/data/geocode_cache.json', encoding='utf-8')); print(f'CONTAINER entries: {len(d)}')\"",
]

for cmd in cmds:
    _, o, _ = ssh.exec_command(cmd, timeout=10)
    o.channel.recv_exit_status()
    print(o.read().decode("utf-8", errors="replace").strip())

# Now try to test the houses_coordinates endpoint with a real UK name
uk_name = 'ООО "ПРЭТ №3"'
import urllib.parse
encoded = urllib.parse.quote(uk_name)
_, o, _ = ssh.exec_command(f'curl -s "http://localhost/api/uk/{encoded}/houses_coordinates" | head -c 500', timeout=15)
o.channel.recv_exit_status()
result = o.read().decode("utf-8", errors="replace").strip()
print(f"\nHouses coords for '{uk_name}': {result[:500]}")

ssh.close()
