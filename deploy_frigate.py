"""
Deploy Frigate + Ollama + LiteLLM to Timeweb server.

Steps:
  1. Upload Frigate config, bridge, LiteLLM config
  2. Upload updated docker-compose.yml
  3. Ensure swap (4GB) for Ollama
  4. Pull Docker images (frigate, ollama, litellm)
  5. Start new services
  6. Load Ollama models (qwen2.5vl:3b, qwen2.5:3b, qwen3:4b-q4_K_M, moondream)
  7. Verify health
"""
import os
import sys
import time

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

try:
    import paramiko
except ImportError:
    print("Installing paramiko...")
    os.system(f"{sys.executable} -m pip install paramiko -q")
    import paramiko

from dotenv import load_dotenv

load_dotenv(r"C:\Soobshio_project\.env")

HOST = os.getenv("TIMEWEB_IP", "45.153.68.59")
USER = os.getenv("TIMEWEB_USER", "root")
PASS = os.getenv("SSH_PASSWORD", "")

PROJECT_DIR = r"C:\Soobshio_project"
REMOTE_APP = "/root/citypulse_api"

# Files to upload
FILES_TO_UPLOAD = [
    # Frigate
    ("ops/frigate/config.yml", f"{REMOTE_APP}/ops/frigate/config.yml"),
    ("ops/frigate/init_ollama_models.sh", f"{REMOTE_APP}/ops/frigate/init_ollama_models.sh"),
    # LiteLLM
    ("ops/litellm_config.yaml", f"{REMOTE_APP}/ops/litellm_config.yaml"),
    # Bridge service
    ("services/frigate_bridge.py", f"{REMOTE_APP}/services/frigate_bridge.py"),
    # Updated watchdog router
    ("services/Backend/routers/watchdog.py", f"{REMOTE_APP}/services/Backend/routers/watchdog.py"),
    # Updated docker-compose
    ("docker-compose.yml", f"{REMOTE_APP}/docker-compose.yml"),
    # Updated camera probe
    ("start_camera_probe.py", f"{REMOTE_APP}/start_camera_probe.py"),
]


def ssh_exec(ssh, cmd, timeout=120):
    """Execute command and print output."""
    print(f"  $ {cmd[:120]}{'...' if len(cmd) > 120 else ''}")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    if out:
        for line in out.split("\n")[-8:]:
            print(f"    {line}")
    if exit_code != 0 and err:
        for line in err.split("\n")[-5:]:
            print(f"    ⚠ {line}")
    return exit_code, out, err


def main():
    if not PASS:
        print("❌ SSH_PASSWORD not found in .env")
        return

    print(f"\n{'='*60}")
    print(f"  🎥 Deploying Frigate + Ollama + LiteLLM to {HOST}")
    print(f"{'='*60}\n")

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        # ────────────────────────────────────────────────────
        # Step 1: Connect
        # ────────────────────────────────────────────────────
        print("1️⃣  Connecting to SSH...")
        ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=15)
        print("   ✅ Connected\n")

        # Quick system check
        print("📊 Server status:")
        ssh_exec(ssh, "free -h | head -3")
        ssh_exec(ssh, "df -h / | tail -1")
        ssh_exec(ssh, "nproc")
        print()

        # ────────────────────────────────────────────────────
        # Step 2: Upload files
        # ────────────────────────────────────────────────────
        print("2️⃣  Uploading Frigate/Ollama/LiteLLM configs...")
        sftp = ssh.open_sftp()

        # Create directories
        ssh_exec(ssh, f"mkdir -p {REMOTE_APP}/ops/frigate {REMOTE_APP}/services/Backend/routers")

        uploaded = 0
        for local_rel, remote_path in FILES_TO_UPLOAD:
            local_path = os.path.join(PROJECT_DIR, local_rel)
            if not os.path.exists(local_path):
                print(f"   ⏭ Skip (not found): {local_rel}")
                continue
            size_kb = os.path.getsize(local_path) / 1024
            print(f"   📤 {local_rel} ({size_kb:.0f} KB)")
            try:
                sftp.put(local_path, remote_path)
                uploaded += 1
            except Exception as e:
                print(f"      ❌ Upload failed: {e}")

        sftp.close()
        print(f"   ✅ {uploaded} files uploaded\n")

        # ────────────────────────────────────────────────────
        # Step 3: Ensure swap (4GB for Ollama)
        # ────────────────────────────────────────────────────
        print("3️⃣  Ensuring 4GB swap for Ollama...")
        ssh_exec(ssh, "swapon --show | head -5")

        swap_cmd = (
            "CURRENT_SWAP=$(swapon --show --bytes | awk 'NR>1{sum+=$3}END{print sum+0}');"
            "if [ \"$CURRENT_SWAP\" -lt 3000000000 ]; then "
            "  swapoff /swapfile 2>/dev/null; "
            "  fallocate -l 4G /swapfile && chmod 600 /swapfile && "
            "  mkswap /swapfile && swapon /swapfile && "
            "  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab && "
            "  echo 'SWAP_UPGRADED_TO_4G'; "
            "else echo 'SWAP_OK'; fi"
        )
        ssh_exec(ssh, swap_cmd)
        ssh_exec(ssh, "free -h | grep Swap")
        print()

        # ────────────────────────────────────────────────────
        # Step 4: Pull Docker images
        # ────────────────────────────────────────────────────
        print("4️⃣  Pulling Docker images (this may take 5-10 minutes)...")

        images = [
            ("ghcr.io/blakeblackshear/frigate:0.14.1", "Frigate NVR"),
            ("ollama/ollama:latest", "Ollama"),
            ("ghcr.io/berriai/litellm:main-stable", "LiteLLM"),
        ]

        for img, label in images:
            print(f"\n   📥 Pulling {label}...")
            code, out, err = ssh_exec(ssh, f"docker pull {img} 2>&1 | tail -5", timeout=600)
            if code == 0:
                print(f"   ✅ {label} ready")
            else:
                print(f"   ⚠️ {label} pull issue (may already exist)")

        print()

        # ────────────────────────────────────────────────────
        # Step 5: Start services
        # ────────────────────────────────────────────────────
        print("5️⃣  Starting Frigate + Ollama + LiteLLM...")

        # Generate LITELLM_MASTER_KEY if not set
        ssh_exec(ssh, f"grep -q 'LITELLM_MASTER_KEY' {REMOTE_APP}/.env 2>/dev/null || "
                      f"echo 'LITELLM_MASTER_KEY=sk-soobshio-local-2026' >> {REMOTE_APP}/.env")

        # Start only the 3 new services (don't restart existing ones)
        code, out, err = ssh_exec(
            ssh,
            f"cd {REMOTE_APP} && docker compose up -d frigate ollama litellm 2>&1 | tail -10",
            timeout=120,
        )

        if code != 0:
            # Fallback to docker-compose v1
            ssh_exec(
                ssh,
                f"cd {REMOTE_APP} && docker-compose up -d frigate ollama litellm 2>&1 | tail -10",
                timeout=120,
            )

        print()
        time.sleep(5)

        # ────────────────────────────────────────────────────
        # Step 6: Load Ollama models
        # ────────────────────────────────────────────────────
        print("6️⃣  Loading AI models into Ollama...")
        print("   ⏳ This downloads ~5.5 GB of models, may take 10-15 min...\n")

        models = [
            ("qwen2.5vl:3b", "Qwen2.5-VL 3B (Vision)", "~2.1 GB"),
            ("qwen2.5:3b", "Qwen2.5 3B (Interactive Text)", "~1.9 GB"),
            ("qwen3:4b-q4_K_M", "Qwen3 4B Q4_K_M (Batch Text)", "~2.6 GB"),
            ("moondream:latest", "Moondream (Lightweight Vision)", "~1.5 GB"),
        ]

        for model_name, label, size in models:
            print(f"   📥 [{size}] {label}...")
            code, out, err = ssh_exec(
                ssh,
                f"docker exec soobshio_ollama ollama pull {model_name} 2>&1 | tail -3",
                timeout=900,  # 15 min per model
            )
            if code == 0:
                print(f"   ✅ {label} loaded")
            else:
                print(f"   ⚠️ {label} pull failed (Ollama may not be ready yet)")
            print()

        # Verify models
        print("   📋 Installed models:")
        ssh_exec(ssh, "docker exec soobshio_ollama ollama list 2>&1")
        print()

        # ────────────────────────────────────────────────────
        # Step 7: Restart camera_probe to activate bridge
        # ────────────────────────────────────────────────────
        print("7️⃣  Restarting camera_probe with Frigate bridge...")
        ssh_exec(
            ssh,
            f"cd {REMOTE_APP} && docker compose restart camera_probe 2>&1 || "
            f"docker-compose restart camera_probe 2>&1",
            timeout=60,
        )
        print()

        # ────────────────────────────────────────────────────
        # Step 8: Verify
        # ────────────────────────────────────────────────────
        print("8️⃣  Verification...")
        time.sleep(5)

        print("\n   🐳 Running containers:")
        ssh_exec(ssh, "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | head -15")

        print("\n   🎥 Frigate health:")
        ssh_exec(ssh, "curl -s http://127.0.0.1:5000/api/version 2>/dev/null || echo 'Frigate starting...'")

        print("\n   🧠 Ollama health:")
        ssh_exec(ssh, "curl -s http://127.0.0.1:11434/api/tags 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(f'Models: {len(d.get(\\\"models\\\",[])))}: '+', '.join(m[\\\"name\\\"] for m in d.get(\\\"models\\\",[])))\" 2>/dev/null || echo 'Ollama starting...'")

        print("\n   🔀 LiteLLM health:")
        ssh_exec(ssh, "curl -s http://127.0.0.1:4000/health 2>/dev/null || echo 'LiteLLM starting...'")

        print("\n   📊 Watchdog API:")
        ssh_exec(ssh, "curl -s http://127.0.0.1:8000/api/watchdog/frigate/health 2>/dev/null | head -5 || echo 'Backend may need restart'")

        print("\n   💾 RAM:")
        ssh_exec(ssh, "free -h")

        print("\n   💿 Disk:")
        ssh_exec(ssh, "df -h / | tail -1")

        print(f"\n{'='*60}")
        print("  ✅ FRIGATE + OLLAMA + LITELLM DEPLOYMENT COMPLETE!")
        print(f"{'='*60}")
        print(f"  API:     http://{HOST}:8080/api/watchdog/status")
        print(f"  Frigate: http://{HOST}:5000 (internal)")
        print(f"  Ollama:  http://{HOST}:11434 (internal)")
        print(f"  LiteLLM: http://{HOST}:4000 (internal)")
        print(f"{'='*60}\n")

    except paramiko.AuthenticationException:
        print(f"\n❌ Authentication failed. Check SSH_PASSWORD in .env")
    except paramiko.SSHException as e:
        print(f"\n❌ SSH Error: {e}")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        ssh.close()


if __name__ == "__main__":
    main()
