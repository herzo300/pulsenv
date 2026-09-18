"""Deeper LiteLLM diagnosis."""

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
    return so.read().decode("utf-8", "ignore").strip()


print("=== LiteLLM Health Log ===", flush=True)
out = run("docker inspect soobshio_litellm --format '{{json .State.Health}}'")
if out:
    try:
        health = json.loads(out)
        for log in health.get("Log", []):
            o = log.get("Output", "")
            safe_o = "".join(c for c in o if ord(c) < 128)
            print(f"  {log.get('End')}: {safe_o}")
    except (json.JSONDecodeError, KeyError, TypeError) as e:
        print(f"  [parse error] {e}")
        print(out)

print("\n=== LiteLLM Logs (Clean) ===", flush=True)
out = run("docker logs soobshio_litellm --tail 50")
safe_out = "".join(c for c in out if ord(c) < 128)
print(safe_out)

ssh.close()
