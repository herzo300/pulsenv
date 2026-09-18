"""Upload geocode_cache.json to server and restart backend."""
import os, sys
import paramiko
from dotenv import load_dotenv

PROJECT_ROOT = r"C:\Soobshio_project"
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

HOST = "45.153.68.59"
USER = "root"
REMOTE_DIR = "/opt/soobshio"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

password = os.getenv("SSH_PASSWORD", "").strip()
if not password:
    print("No SSH_PASSWORD in .env")
    sys.exit(1)

print(f"Connecting to {HOST}...")
ssh.connect(hostname=HOST, username=USER, password=password, timeout=15,
            look_for_keys=False, allow_agent=False, banner_timeout=30)
print("Connected!")

# Upload geocode cache
local = os.path.join(PROJECT_ROOT, "data", "geocode_cache.json")
remote = f"{REMOTE_DIR}/data/geocode_cache.json"
print(f"Uploading {local} -> {remote}...")
sftp = ssh.open_sftp()
sftp.put(local, remote)
size = os.path.getsize(local)
print(f"Uploaded! ({size:,} bytes)")
sftp.close()

# Restart backend container
print("\nRestarting backend container...")
stdin, stdout, stderr = ssh.exec_command(
    f"cd {REMOTE_DIR} && docker compose restart backend 2>&1", timeout=60
)
exit_code = stdout.channel.recv_exit_status()
out = stdout.read().decode("utf-8", errors="replace").strip()
print(out)

# Verify health
print("\nChecking health...")
stdin, stdout, stderr = ssh.exec_command("curl -s http://localhost/health", timeout=10)
stdout.channel.recv_exit_status()
print(stdout.read().decode("utf-8", errors="replace").strip())

ssh.close()
print("\nDone!")
