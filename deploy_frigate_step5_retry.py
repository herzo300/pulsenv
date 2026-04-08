"""Wait for and start Frigate services on the server."""
import sys, os, time
sys.path.insert(0, r"C:\Soobshio_project")
from dotenv import load_dotenv
load_dotenv(r"C:\Soobshio_project\.env")
import paramiko

def run(ssh, cmd):
    print(f"$ {cmd}", flush=True)
    si, so, se = ssh.exec_command(cmd)
    out = so.read().decode("utf-8", "replace").strip()
    err = se.read().decode("utf-8", "replace").strip()
    if out: print(f"  {out}", flush=True)
    if err: print(f"  W: {err}", flush=True)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=os.getenv("TIMEWEB_IP"), username="root", password=os.getenv("SSH_PASSWORD"), timeout=15)
print("Connected!", flush=True)

REMOTE_APP = "/root/citypulse_api"
LOCAL = r"C:\Soobshio_project"

# Upload NEW docker-compose.yml
print("Uploading new docker-compose.yml...", flush=True)
sftp = ssh.open_sftp()
sftp.put(os.path.join(LOCAL, "docker-compose.yml"), f"{REMOTE_APP}/docker-compose.yml")
sftp.close()

# Start
print("\nStarting services...", flush=True)
run(ssh, f"cd {REMOTE_APP} && docker compose up -d frigate ollama litellm")

print("\nStatus:", flush=True)
run(ssh, "docker ps --format 'table {{.Names}}\t{{.Status}}'")

# Also restart camera_probe since it was the one modified to bridge
print("\nRestarting camera_probe...", flush=True)
run(ssh, f"cd {REMOTE_APP} && docker compose restart camera_probe")

ssh.close()
"Done."
