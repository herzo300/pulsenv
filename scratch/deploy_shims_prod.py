#!/usr/bin/env python3
"""Upload hermes shims to prod and restart backend."""
import paramiko
import time

VPS = ("45.153.68.59", 22, "root", "sf?UQ8AYk*-DB8")
FILES = [
    ("services/hermes_agent_crew.py", "/opt/soobshio/services/hermes_agent_crew.py"),
    ("services/hermes_skills_engine.py", "/opt/soobshio/services/hermes_skills_engine.py"),
]

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(VPS[0], VPS[1], VPS[2], VPS[3], timeout=30)
sftp = ssh.open_sftp()
for local, remote in FILES:
    sftp.put(local, remote)
    print("uploaded:", remote)
sftp.close()

stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/soobshio && docker compose restart backend", timeout=180)
print(stdout.read().decode(), stderr.read().decode())
time.sleep(10)
stdin, stdout, stderr = ssh.exec_command(
    "docker ps --filter name=soobshio_backend --format '{{.Names}} {{.Status}}'")
print(stdout.read().decode())
ssh.close()
print("DEPLOY DONE")
