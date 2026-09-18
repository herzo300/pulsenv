"""Load specific verified Ollama models."""

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
    print(f"$ {cmd}", flush=True)
    _, so, se = ssh.exec_command(cmd)
    out = so.read().decode("utf-8", "ignore")
    # Clean up non-ascii
    safe_out = "".join(c for c in out if ord(c) < 128).strip()
    if safe_out:
        print(f"  {safe_out}", flush=True)


# Gemma 4 E4B replaces: qwen2.5:3b, qwen2.5vl:3b, qwen3:4b, moondream
models = ["gemma4:4b"]
for m in models:
    run(f"docker exec soobshio_ollama ollama pull {m}")

print("\n=== Final Model List ===", flush=True)
run("docker exec soobshio_ollama ollama list")

ssh.close()
