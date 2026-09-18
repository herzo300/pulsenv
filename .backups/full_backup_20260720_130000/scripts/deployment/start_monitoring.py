"""Start monitoring profile on production VPS."""

from __future__ import annotations

import json
import os
import sys

import httpx
import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

load_dotenv(r"C:\Soobshio_project\.env")
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()
REMOTE = "/root/citypulse_api"


def main() -> int:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(
        "45.153.68.59",
        username="root",
        password=PASSWORD,
        timeout=25,
        look_for_keys=False,
        allow_agent=False,
    )
    commands = [
        f"cd {REMOTE} && docker compose --profile monitoring up -d monitoring 2>&1 | tail -15",
        f"cd {REMOTE} && docker compose ps monitoring 2>&1",
        "sleep 4 && docker logs soobshio_monitoring --tail 25 2>&1",
    ]
    for cmd in commands:
        print(f"\n$ {cmd}")
        _, stdout, stderr = ssh.exec_command(cmd, timeout=120)
        out = stdout.read().decode("utf-8", errors="replace").strip()
        err = stderr.read().decode("utf-8", errors="replace").strip()
        if out:
            print(out)
        if err:
            print(err)
    ssh.close()

    status = httpx.get(
        "http://45.153.68.59/api/runtime/monitoring-status",
        timeout=20,
    ).json()
    print("\nmonitoring-status:", json.dumps(status, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
