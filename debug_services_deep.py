"""Frigate and Ollama deep inspection."""
import os, paramiko, json
from dotenv import load_dotenv
load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=os.getenv("TIMEWEB_IP"), username="root", password=os.getenv("SSH_PASSWORD"))

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
    except:
        print(out)

print("\n=== Frigate Exit Code ===", flush=True)
out, _ = run("docker inspect soobshio_frigate --format '{{.State.ExitCode}} {{.State.Error}}'")
print(out)

print("\n=== Frigate Logs (Attempt 2) ===", flush=True)
out, err = run("docker logs soobshio_frigate")
print(f"STDOUT: {out}\nSTDERR: {err}")

ssh.close()
