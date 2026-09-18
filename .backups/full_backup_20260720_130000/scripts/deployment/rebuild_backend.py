"""Rebuild the backend Docker image to include geo_service.py fix."""
import os, sys
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

print("Rebuilding backend Docker image with updated geo_service.py...")
_, o, e = ssh.exec_command(
    "cd /opt/soobshio && docker compose up -d --build backend 2>&1 | tail -20",
    timeout=120
)
exit_code = o.channel.recv_exit_status()
print(o.read().decode("utf-8", errors="replace").strip())

ssh.close()
print("\nDone!")
