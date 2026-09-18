"""Clean Docker disk space and rebuild backend."""
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

cmds = [
    ("Disk space before:", "df -h / | tail -1"),
    ("Cleaning Docker...", "docker system prune -f 2>&1 | tail -5"),
    ("Removing dangling images...", "docker image prune -af 2>&1 | tail -5"),
    ("Disk space after:", "df -h / | tail -1"),
    ("Rebuilding backend...", "cd /opt/soobshio && docker compose up -d --build backend 2>&1 | tail -20"),
]

for label, cmd in cmds:
    print(f"\n{label}")
    _, o, _ = ssh.exec_command(cmd, timeout=180)
    o.channel.recv_exit_status()
    print(o.read().decode("utf-8", errors="replace").strip())

ssh.close()
print("\nDone!")
