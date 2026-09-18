import os
import paramiko
from dotenv import load_dotenv

PROJECT_ROOT = r"C:\Soobshio_project"
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

HOST = "45.153.68.59"
USER = "root"
PASSWORD = os.getenv("SSH_PASSWORD", "sf?UQ8AYk*-DB8")

print(f"Connecting to {HOST}...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USER, password=PASSWORD, timeout=20)

print("Running docker compose up -d...")
stdin, stdout, stderr = ssh.exec_command("cd /opt/soobshio && docker compose up -d")
exit_code = stdout.channel.recv_exit_status()

print("STDOUT:")
print(stdout.read().decode(errors="replace"))
print("STDERR:")
print(stderr.read().decode(errors="replace"))

ssh.close()
print("Done!")
