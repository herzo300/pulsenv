"""Stack Health Check."""

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


print("1. Frigate Version:", run("curl -s http://127.0.0.1:5000/api/version"))
print(
    "2. Ollama Tags:",
    "OK" if "models" in run("curl -s http://127.0.0.1:11434/api/tags") else "FAILED",
)
print(
    "3. LiteLLM Health:",
    "OK"
    if "working" in run("curl -s http://127.0.0.1:4000/health").lower()
    else "FAILED",
)
ssh.close()
