"""Load Ollama models and verify API."""
import os, paramiko, time
from dotenv import load_dotenv
load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=os.getenv("TIMEWEB_IP"), username="root", password=os.getenv("SSH_PASSWORD"))

def run(cmd, t=900):
    print(f"$ {cmd}", flush=True)
    si, so, se = ssh.exec_command(cmd, timeout=t)
    out = so.read().decode("utf-8", "replace")
    err = se.read().decode("utf-8", "replace")
    # Clean up non-printable and special characters for Windows console
    safe_out = out.encode("ascii", "ignore").decode("ascii")
    safe_err = err.encode("ascii", "ignore").decode("ascii")
    if safe_out.strip(): print(f"  {safe_out.strip()}", flush=True)
    if safe_err.strip(): print(f"  W: {safe_err.strip()}", flush=True)

print("=== Loading AI Models (Gemma 4) ===", flush=True)
# Gemma 4 E4B replaces: qwen2.5:3b (text), qwen2.5vl:3b (vision), moondream (lightweight)
# Single model handles both text classification and vision analysis
models = ["gemma4:4b"]
for m in models:
    run(f"docker exec soobshio_ollama ollama pull {m}")

print("\n=== Verifying Models ===", flush=True)
run("docker exec soobshio_ollama ollama list")

print("\n=== Verifying LiteLLM Proxy ===", flush=True)
run("curl -s http://127.0.0.1:4000/health")

print("\n=== Verifying Watchdog API Status ===", flush=True)
run("curl -s http://127.0.0.1:8000/api/watchdog/status")

ssh.close()
