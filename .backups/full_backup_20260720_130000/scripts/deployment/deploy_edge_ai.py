"""
Deploy Edge AI + SmolVLM to Timeweb server.
Steps:
  1. Upload YOLO model (yolov8n.onnx)
  2. Upload updated project files
  3. Setup swap (2GB) for SmolVLM
  4. Download SmolVLM-256M GGUF
  5. Rebuild Docker
  6. Check logs
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

# Files to upload (relative to PROJECT_DIR)
FILES_TO_UPLOAD = [
    ("models/yolov8n.onnx", f"{REMOTE_APP}/models/yolov8n.onnx"),
    ("services/yolo_edge_filter.py", f"{REMOTE_APP}/services/yolo_edge_filter.py"),
    (
        "services/push_notification_service.py",
        f"{REMOTE_APP}/services/push_notification_service.py",
    ),
    ("requirements.txt", f"{REMOTE_APP}/requirements.txt"),
    ("Dockerfile", f"{REMOTE_APP}/Dockerfile"),
    (".env", f"{REMOTE_APP}/.env"),
    ("start_all_monitoring.py", f"{REMOTE_APP}/start_all_monitoring.py"),
    ("services/zai_service.py", f"{REMOTE_APP}/services/zai_service.py"),
    ("services/zai_vision_service.py", f"{REMOTE_APP}/services/zai_vision_service.py"),
    ("services/geo_service.py", f"{REMOTE_APP}/services/geo_service.py"),
    ("services/smolvlm_service.py", f"{REMOTE_APP}/services/smolvlm_service.py"),
    (
        "services/Backend/routers/payments.py",
        f"{REMOTE_APP}/services/Backend/routers/payments.py",
    ),
]


def ssh_exec(ssh, cmd, timeout=120):
    """Execute command and print output."""
    print(f"  $ {cmd[:100]}{'...' if len(cmd) > 100 else ''}")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    if out:
        for line in out.split("\n")[-5:]:
            print(f"    {line}")
    if exit_code != 0 and err:
        for line in err.split("\n")[-3:]:
            print(f"    вљ  {line}")
    return exit_code, out, err


def main():
    if not PASS:
        print("вќЊ SSH_PASSWORD not found in .env")
        return

    print(f"\nрџљЂ Deploying Edge AI to {HOST}...\n")

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        print("1пёЏвѓЈ Connecting to SSH...")
        ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=15)
        print("   вњ… Connected\n")

        # в”Ђв”Ђ Step 2: Upload files в”Ђв”Ђ
        print("2пёЏвѓЈ Uploading files...")
        sftp = ssh.open_sftp()

        # Ensure remote directories exist
        ssh_exec(
            ssh, f"mkdir -p {REMOTE_APP}/models {REMOTE_APP}/services/Backend/routers"
        )

        uploaded = 0
        for local_rel, remote_path in FILES_TO_UPLOAD:
            local_path = os.path.join(PROJECT_DIR, local_rel)
            if not os.path.exists(local_path):
                print(f"   вЏ­ Skip (not found): {local_rel}")
                continue
            size_kb = os.path.getsize(local_path) / 1024
            print(f"   рџ“¤ {local_rel} ({size_kb:.0f} KB) в†’ {remote_path}")
            try:
                sftp.put(local_path, remote_path)
                uploaded += 1
            except Exception as e:
                print(f"      вќЊ Upload failed: {e}")

        sftp.close()
        print(f"   вњ… {uploaded} files uploaded\n")

        # в”Ђв”Ђ Step 3: Setup swap for SmolVLM в”Ђв”Ђ
        print("3пёЏвѓЈ Setting up 2GB swap for SmolVLM...")
        ssh_exec(ssh, "swapon --show | head -3")
        swap_cmds = [
            "if [ ! -f /swapfile ]; then fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab && echo 'SWAP CREATED'; else echo 'SWAP EXISTS'; fi",
        ]
        for cmd in swap_cmds:
            ssh_exec(ssh, cmd)
        print()

        # в”Ђв”Ђ Step 4: Download SmolVLM-256M GGUF в”Ђв”Ђ
        print("4пёЏвѓЈ Downloading SmolVLM-256M GGUF model...")
        smolvlm_dir = f"{REMOTE_APP}/models"
        smolvlm_model = f"{smolvlm_dir}/smolvlm-256m-instruct-q4_k_m.gguf"
        smolvlm_mmproj = f"{smolvlm_dir}/smolvlm-256m-mmproj.gguf"

        # Check if already downloaded
        code, out, _ = ssh_exec(
            ssh, f"ls -la {smolvlm_model} 2>/dev/null && echo EXISTS || echo MISSING"
        )

        if "MISSING" in out:
            print("   рџ“Ґ Downloading SmolVLM-256M model (~500MB)...")
            # Download from HuggingFace ggml-org
            dl_cmds = [
                "apt-get install -y wget 2>/dev/null",
                f"wget -q --show-progress -O {smolvlm_model} 'https://huggingface.co/ggml-org/SmolVLM-256M-Instruct-GGUF/resolve/main/SmolVLM-256M-Instruct-Q4_K_M.gguf' || echo 'DL_FAIL'",
                f"wget -q --show-progress -O {smolvlm_mmproj} 'https://huggingface.co/ggml-org/SmolVLM-256M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-256M-Instruct-f16.gguf' || echo 'DL_FAIL'",
            ]
            for cmd in dl_cmds:
                ssh_exec(ssh, cmd, timeout=300)

            # Verify
            ssh_exec(
                ssh, f"ls -lh {smolvlm_dir}/*.gguf 2>/dev/null || echo 'No GGUF files'"
            )
        else:
            print("   вњ… SmolVLM-256M already downloaded")

        # в”Ђв”Ђ Step 5: Install llama.cpp server в”Ђв”Ђ
        print("\n5пёЏвѓЈ Installing llama.cpp for SmolVLM inference...")
        llama_cmds = [
            # Install pre-built binary
            "if ! command -v llama-server 2>/dev/null; then "
            "apt-get install -y cmake build-essential 2>/dev/null && "
            "cd /tmp && rm -rf llama.cpp && "
            "git clone --depth 1 https://github.com/ggml-org/llama.cpp.git && "
            "cd llama.cpp && cmake -B build -DGGML_CPU=ON -DLLAMA_CURL=OFF && "
            "cmake --build build --config Release -j2 && "
            "cp build/bin/llama-server /usr/local/bin/ && "
            "cp build/bin/llama-cli /usr/local/bin/ && "
            "echo 'LLAMA_INSTALLED'; "
            "else echo 'LLAMA_EXISTS'; fi",
        ]
        for cmd in llama_cmds:
            ssh_exec(ssh, cmd, timeout=600)

        print()

        # в”Ђв”Ђ Step 6: Create SmolVLM systemd service в”Ђв”Ђ
        print("6пёЏвѓЈ Creating SmolVLM service...")
        smolvlm_service = f"""[Unit]
Description=SmolVLM-256M Vision Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server \\
  -m {smolvlm_model} \\
  --mmproj {smolvlm_mmproj} \\
  --host 127.0.0.1 \\
  --port 8090 \\
  -ngl 0 \\
  -c 512 \\
  -t 2 \\
  --no-mmap
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
"""
        # Write service file
        ssh_exec(
            ssh,
            f"cat > /etc/systemd/system/smolvlm.service << 'SERVICEEOF'\n{smolvlm_service}\nSERVICEEOF",
        )
        ssh_exec(
            ssh,
            "systemctl daemon-reload && systemctl enable smolvlm && systemctl restart smolvlm",
        )
        time.sleep(3)
        ssh_exec(ssh, "systemctl status smolvlm --no-pager -l | head -15")
        print()

        # в”Ђв”Ђ Step 7: Rebuild Docker в”Ђв”Ђ
        print("7пёЏвѓЈ Rebuilding Docker containers...")
        ssh_exec(
            ssh,
            f"cd {REMOTE_APP} && docker compose down 2>/dev/null; docker-compose down 2>/dev/null; echo 'DOWN'",
        )
        code, out, err = ssh_exec(
            ssh,
            f"cd {REMOTE_APP} && docker compose build --no-cache 2>&1 | tail -10",
            timeout=600,
        )
        if code != 0:
            # Fallback to docker-compose v1
            ssh_exec(
                ssh,
                f"cd {REMOTE_APP} && docker-compose build --no-cache 2>&1 | tail -10",
                timeout=600,
            )

        ssh_exec(
            ssh,
            f"cd {REMOTE_APP} && docker compose up -d 2>/dev/null || docker-compose up -d",
        )
        print()

        # в”Ђв”Ђ Step 8: Verify в”Ђв”Ђ
        print("8пёЏвѓЈ Verifying deployment...")
        time.sleep(5)
        ssh_exec(
            ssh,
            "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | head -10",
        )
        print()

        print("рџ“‹ Recent logs:")
        ssh_exec(
            ssh,
            f"cd {REMOTE_APP} && docker compose logs --tail 30 2>/dev/null || docker-compose logs --tail 30 2>/dev/null | tail -30",
        )
        print()

        # Check SmolVLM
        print("рџ§  SmolVLM status:")
        ssh_exec(
            ssh,
            "curl -s http://127.0.0.1:8090/health 2>/dev/null || echo 'SmolVLM not ready yet (may take 30s to load)'",
        )
        print()

        # RAM check
        print("рџ’ѕ Server RAM usage:")
        ssh_exec(ssh, "free -h")

        print("\n" + "=" * 50)
        print("вњ… DEPLOYMENT COMPLETE!")
        print(f"   API: http://{HOST}:8080")
        print("   SmolVLM: http://127.0.0.1:8090 (internal)")
        print("=" * 50)

    except Exception as e:
        print(f"\nвќЊ Error: {e}")
        import traceback

        traceback.print_exc()
    finally:
        ssh.close()


if __name__ == "__main__":
    main()

