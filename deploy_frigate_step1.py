"""Quick Frigate deploy - unbuffered output."""
import sys, os, time
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, r"C:\Soobshio_project")
from dotenv import load_dotenv
load_dotenv(r"C:\Soobshio_project\.env")
import paramiko

HOST = os.getenv("TIMEWEB_IP", "45.153.68.59")
PASS = os.getenv("SSH_PASSWORD", "")
REMOTE_APP = "/root/citypulse_api"
LOCAL = r"C:\Soobshio_project"

def run(ssh, cmd, t=120):
    print(f"$ {cmd[:140]}", flush=True)
    si, so, se = ssh.exec_command(cmd, timeout=t)
    code = so.channel.recv_exit_status()
    out = so.read().decode("utf-8", "replace").strip()
    err = se.read().decode("utf-8", "replace").strip()
    if out:
        for l in out.split("\n")[-8:]:
            print(f"  {l}", flush=True)
    if code != 0 and err:
        for l in err.split("\n")[-4:]:
            print(f"  W: {l}", flush=True)
    return code, out

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username="root", password=PASS, timeout=15)
print("Connected!", flush=True)

# Step 1: System
print("\n=== Step 1: System Check ===", flush=True)
run(ssh, "free -h")
run(ssh, "swapon --show")

# Step 2: Upload files
print("\n=== Step 2: Upload files ===", flush=True)
run(ssh, f"mkdir -p {REMOTE_APP}/ops/frigate {REMOTE_APP}/services/Backend/routers")
sftp = ssh.open_sftp()
files = [
    ("ops/frigate/config.yml", f"{REMOTE_APP}/ops/frigate/config.yml"),
    ("ops/litellm_config.yaml", f"{REMOTE_APP}/ops/litellm_config.yaml"),
    ("services/frigate_bridge.py", f"{REMOTE_APP}/services/frigate_bridge.py"),
    ("services/Backend/routers/watchdog.py", f"{REMOTE_APP}/services/Backend/routers/watchdog.py"),
    ("docker-compose.yml", f"{REMOTE_APP}/docker-compose.yml"),
    ("start_camera_probe.py", f"{REMOTE_APP}/start_camera_probe.py"),
]
for lr, rp in files:
    lp = os.path.join(LOCAL, lr)
    if os.path.exists(lp):
        sftp.put(lp, rp)
        print(f"  uploaded: {lr}", flush=True)
sftp.close()

# Step 3: Swap
print("\n=== Step 3: Ensure 4GB Swap ===", flush=True)
swap_cmd = (
    "CURRENT=$(stat -c%s /swapfile 2>/dev/null || echo 0); "
    "if [ \"$CURRENT\" -lt 3000000000 ]; then "
    "swapoff /swapfile 2>/dev/null; "
    "fallocate -l 4G /swapfile && chmod 600 /swapfile && "
    "mkswap /swapfile && swapon /swapfile && echo SWAP_4G_OK; "
    "else echo SWAP_ALREADY_OK; fi"
)
run(ssh, swap_cmd)
run(ssh, "free -h | grep -i swap")

# Step 4: Pull Docker images
print("\n=== Step 4: Pull Docker Images ===", flush=True)
images = [
    ("ghcr.io/blakeblackshear/frigate:0.14.1", "Frigate"),
    ("ollama/ollama:latest", "Ollama"),
    ("ghcr.io/berriai/litellm:main-stable", "LiteLLM"),
]
for img, label in images:
    print(f"\nPulling {label}...", flush=True)
    run(ssh, f"docker pull {img} 2>&1 | tail -3", t=600)

# Step 5: Env vars
print("\n=== Step 5: Env + Start ===", flush=True)
env_cmds = [
    f"grep -q LITELLM_MASTER_KEY {REMOTE_APP}/.env || echo LITELLM_MASTER_KEY=sk-soobshio-local-2026 >> {REMOTE_APP}/.env",
    f"grep -q FRIGATE_ENABLED {REMOTE_APP}/.env || echo FRIGATE_ENABLED=true >> {REMOTE_APP}/.env",
    f"grep -q FRIGATE_URL {REMOTE_APP}/.env || echo FRIGATE_URL=http://frigate:5000 >> {REMOTE_APP}/.env",
    f"grep -q LITELLM_URL {REMOTE_APP}/.env || echo LITELLM_URL=http://litellm:4000 >> {REMOTE_APP}/.env",
]
for cmd in env_cmds:
    run(ssh, cmd)

# Start
run(ssh, f"cd {REMOTE_APP} && docker compose up -d frigate ollama litellm 2>&1 | tail -10", t=120)

print("\nWaiting 10s for startup...", flush=True)
time.sleep(10)
run(ssh, 'docker ps --format "table {{.Names}}\t{{.Status}}" | head -15')

ssh.close()
print("\n=== Steps 1-5 DONE ===", flush=True)
