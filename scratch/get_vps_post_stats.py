# scratch/get_vps_post_stats.py — Query raw post count from VPS production monitoring log
import os
import sys
import paramiko
from dotenv import load_dotenv

PROJECT_ROOT = r"C:\Soobshio_project"
sys.stdout.reconfigure(encoding='utf-8')
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

HOST = "45.153.68.59"
USER = "root"
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASSWORD, timeout=15)

# Query today's channel posts directly on VPS
cmd = "docker compose -f /opt/soobshio/docker-compose.yml exec -T backend python scripts/maintenance/check_telegram_access.py"
_, stdout, stderr = ssh.exec_command(cmd)

logs = stdout.read().decode('utf-8', errors='replace')
print("=== VPS DIRECT CHANNEL SCAN RESULT ===")
print(logs)

ssh.close()
