"""Debug geocode cache on server."""
import os, sys
import paramiko
from dotenv import load_dotenv

load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname="45.153.68.59", username="root",
            password=os.getenv("SSH_PASSWORD", "").strip(),
            timeout=15, look_for_keys=False, allow_agent=False)

cmds = [
    # Check file on host
    "ls -la /opt/soobshio/data/geocode_cache.json",
    "python3 -c \"import json; d=json.load(open('/opt/soobshio/data/geocode_cache.json')); print(f'Host cache: {len(d)} entries')\"",
    # Check file inside container
    "docker exec soobshio_backend ls -la /app/data/geocode_cache.json 2>&1",
    "docker exec soobshio_backend python3 -c \"import json; d=json.load(open('/app/data/geocode_cache.json')); print(f'Container cache: {len(d)} entries')\" 2>&1",
    # Check docker-compose volume mounts
    "docker inspect soobshio_backend --format='{{json .Mounts}}' 2>&1 | python3 -m json.tool 2>/dev/null || docker inspect soobshio_backend --format='{{json .Mounts}}' 2>&1",
    # Check what the houses_coordinates endpoint actually does
    "docker logs soobshio_backend --tail 30 2>&1",
]

for cmd in cmds:
    print(f"\n$ {cmd[:80]}")
    _, o, e = ssh.exec_command(cmd, timeout=15)
    o.channel.recv_exit_status()
    out = o.read().decode("utf-8", errors="replace").strip()
    err = e.read().decode("utf-8", errors="replace").strip()
    if out: print(out)
    if err: print(f"STDERR: {err}")

ssh.close()
