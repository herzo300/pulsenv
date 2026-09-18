#!/usr/bin/env python3
"""Run DB maintenance on production via SSH (inside backend container)."""

from __future__ import annotations

import os
import sys

import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
load_dotenv(os.path.join(ROOT, ".env"))

HOST = os.getenv("PROD_SSH_HOST", "45.153.68.59").strip()
USER = os.getenv("PROD_SSH_USER", "root").strip()
REMOTE = os.getenv("PROD_COMPOSE_DIR", "/root/citypulse_api").strip()
BACKEND = os.getenv("PROD_BACKEND_CONTAINER", "soobshio_backend").strip()
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()


def run(ssh: paramiko.SSHClient, cmd: str, timeout: int = 300) -> tuple[int, str]:
    print(f"\n$ {cmd[:120]}")
    _, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    code = stdout.channel.recv_exit_status()
    if out.strip():
        print(out.strip())
    if err.strip() and code != 0:
        print("ERR:", err.strip()[-2000:])
    return code, out


def main() -> int:
    if not PASSWORD:
        print("[ERROR] SSH_PASSWORD missing in .env", file=sys.stderr)
        return 1

    extra = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "--apply --vacuum"
    if "--apply" not in extra:
        extra = f"--apply {extra}"

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(
        HOST,
        username=USER,
        password=PASSWORD,
        timeout=25,
        look_for_keys=False,
        allow_agent=False,
    )

    local_script = os.path.join(ROOT, "scripts", "maintenance", "maintain_database.py")
    remote_script = f"{REMOTE}/scripts/maintenance/maintain_database.py"
    sftp = ssh.open_sftp()
    sftp.put(local_script, remote_script)
    sftp.close()

    run(ssh, f"docker exec {BACKEND} mkdir -p /app/scripts/maintenance")
    run(ssh, f"docker cp {remote_script} {BACKEND}:/app/scripts/maintenance/maintain_database.py")
    code, _ = run(
        ssh,
        f"docker exec -w /app {BACKEND} python scripts/maintenance/maintain_database.py {extra}",
        timeout=600,
    )
    if code == 0:
        run(ssh, f"cd {REMOTE} && docker compose restart backend")
    ssh.close()
    return code


if __name__ == "__main__":
    raise SystemExit(main())
