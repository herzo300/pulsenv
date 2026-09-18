"""Diagnose and fix prod backend DB auth."""

from __future__ import annotations

import os
import sys

import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

load_dotenv(r"C:\Soobshio_project\.env")
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()
REMOTE = "/root/citypulse_api"


def run(ssh, cmd: str) -> str:
    print(f"\n$ {cmd[:100]}")
    _, o, e = ssh.exec_command(cmd, timeout=120)
    out = o.read().decode("utf-8", errors="replace")
    err = e.read().decode("utf-8", errors="replace")
    if out.strip():
        print(out.strip()[:3000])
    if err.strip():
        print("ERR:", err.strip()[:1500])
    return out


def main() -> int:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect("45.153.68.59", username="root", password=PASSWORD, timeout=25, look_for_keys=False, allow_agent=False)

    run(ssh, f"grep -E '^(POSTGRES_PASSWORD|DATABASE_URL)=' {REMOTE}/.env | sed 's/=.*/=***/'")
    run(ssh, "docker exec soobshio_backend printenv DATABASE_URL | sed 's/:[^:@]*@/:***@/'")
    run(
        ssh,
        "docker exec soobshio_backend python -c \""
        "from services.data_layer.database import SessionLocal;"
        "from services.data_layer.models import Report;"
        "db=SessionLocal();"
        "print('reports', db.query(Report).count());"
        "db.close()\"",
    )

    # Align backend password with postgres volume password via .env
    run(
        ssh,
        f"cd {REMOTE} && "
        "POSTGRES_PASS=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2-) && "
        "docker exec soobshio_postgres psql -U soobshio -d soobshio -c \"SELECT 1\" >/dev/null && "
        "echo postgres_ok",
    )

    ssh.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
