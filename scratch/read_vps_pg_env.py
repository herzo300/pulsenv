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

stdin, stdout, stderr = ssh.exec_command("grep -E 'POSTGRES|DATABASE_URL' /opt/soobshio/.env")
print("ENV:")
print(stdout.read().decode('utf-8'))

ssh.close()
