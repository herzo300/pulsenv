"""Diagnostics for failed health check."""

import os

import paramiko
from dotenv import load_dotenv

load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(
    hostname=os.getenv("TIMEWEB_IP"),
    username="root",
    password=os.getenv("SSH_PASSWORD"),
)


def run(cmd):
    _, so, se = ssh.exec_command(cmd)
    return so.read().decode("utf-8", "ignore").strip(), se.read().decode(
        "utf-8", "ignore"
    ).strip()


print("=== Docker PS (Ports) ===", flush=True)
out, err = run("docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'")
print(out, flush=True)

print("=== Netstat (Ports) ===", flush=True)
out, err = run("netstat -tulpn | grep -E '5000|11434|4000|8000'")
print(out, flush=True)

ssh.close()
