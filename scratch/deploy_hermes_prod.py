#!/usr/bin/env python3
"""Deploy hermes routing chain (crew + rag + dispatcher) to prod VPS."""
import paramiko
import time

VPS = ("45.153.68.59", 22, "root", "sf?UQ8AYk*-DB8")
FILES = [
    ("services/Backend/services/hermes_agent_crew.py",
     "/opt/soobshio/services/Backend/services/hermes_agent_crew.py"),
    ("services/ai/rag_city_assistant.py",
     "/opt/soobshio/services/ai/rag_city_assistant.py"),
    ("services/Backend/routers/dispatcher.py",
     "/opt/soobshio/services/Backend/routers/dispatcher.py"),
]

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(VPS[0], VPS[1], VPS[2], VPS[3], timeout=30)

ts = time.strftime("%Y%m%d_%H%M%S")
for _, remote in FILES:
    ssh.exec_command(f"cp {remote} {remote}.bak_{ts}")
print(f"backups: *.bak_{ts}")

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
    "docker ps --filter name=soobshio_backend --format '{{.Names}} {{.Status}}' && "
    "docker logs soobshio_backend --tail 5 2>&1")
print(stdout.read().decode())
ssh.close()
print("DEPLOY DONE")
