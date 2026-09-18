"""Viseron and Ollama deep inspection."""

import json
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
    return so.read().decode().strip(), se.read().decode().strip()


print("=== Ollama Health Log ===", flush=True)
out, _ = run("docker inspect soobshio_ollama --format '{{json .State.Health}}'")
if out:
    try:
        health = json.loads(out)
        for log in health.get("Log", []):
            print(f"  {log.get('End')}: {log.get('Output')}")
    except (json.JSONDecodeError, KeyError, TypeError) as e:
        print(f"  [parse error] {e}")
        print(out)

print("\n=== Viseron container ===", flush=True)
out, _ = run(
    "docker inspect soobshio_viseron --format '{{.State.Status}} exit={{.State.ExitCode}}' 2>/dev/null || echo 'not running'"
)
print(out)

print("\n=== Viseron logs (tail) ===", flush=True)
out, err = run("docker logs soobshio_viseron 2>&1 | tail -30")
print(f"STDOUT: {out}\nSTDERR: {err}")

print("\n=== Viseron API status ===", flush=True)
out, _ = run("curl -s http://127.0.0.1:8888/ 2>/dev/null | head -c 200 || echo 'unreachable'")
print(out)

ssh.close()
