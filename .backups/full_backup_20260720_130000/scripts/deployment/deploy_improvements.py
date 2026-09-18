"""Deploy recent improvements to production VPS."""

from __future__ import annotations

import os
import sys
from pathlib import Path

import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT = Path(r"C:\Soobshio_project")
HOST = "45.153.68.59"
USER = "root"
REMOTE = "/root/citypulse_api"

load_dotenv(PROJECT / ".env")
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()
if not PASSWORD:
    print("[ERROR] SSH_PASSWORD missing in .env")
    sys.exit(1)

DIRS = [
    "public",
    "data",
    "services/Backend",
    "services/business",
    "services/monitoring",
    "services/ai",
    "scripts/maintenance",
    "services/data_layer",
    "core",
    "alembic",
    "ops/viseron",
    ".github/workflows",
]

SKIP_DIR_NAMES = {"__pycache__", ".pytest_cache", ".git", "node_modules"}

FILES = [
    "scripts/deployment/fix_db_now.py",
    "start_camera_probe.py",
    "requirements.txt",
    "docker-compose.yml",
    "alembic.ini",
    "scripts/deployment/bootstrap_production.sh",
    "scripts/deployment/deploy_improvements.py",
    "PROJECT_STRUCTURE.md",
    ".env.production.template",
]


def sync_tree(sftp, ssh, local: Path, remote_rel: str) -> int:
    count = 0
    remote_base = f"{REMOTE}/{remote_rel}".replace("\\", "/")
    for root, dirs, files in os.walk(local):
        dirs[:] = [d for d in dirs if d not in SKIP_DIR_NAMES]
        rel = Path(root).relative_to(local)
        remote_dir = remote_base if str(rel) == "." else f"{remote_base}/{rel.as_posix()}"
        try:
            sftp.stat(remote_dir)
        except OSError:
            ssh.exec_command(f"mkdir -p {remote_dir}")
        for name in files:
            if name.endswith((".pyc", ".pyo")):
                continue
            lp = Path(root) / name
            rp = f"{remote_dir}/{name}"
            sftp.put(str(lp), rp)
            count += 1
            print(f"  [OK] {remote_rel}/{rel.as_posix()}/{name}".replace("/./", "/"))
    return count


def main() -> None:
    print("=" * 60)
    print("  Soobshio — полный деплой улучшений")
    print(f"  {HOST} → {REMOTE}")
    print("=" * 60)

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(
        HOST,
        username=USER,
        password=PASSWORD,
        timeout=20,
        look_for_keys=False,
        allow_agent=False,
    )
    sftp = ssh.open_sftp()
    uploaded = 0

    for rel in DIRS:
        local = PROJECT / rel
        if not local.exists():
            print(f"  [SKIP] dir {rel}")
            continue
        print(f"\nSync {rel}/ ...")
        uploaded += sync_tree(sftp, ssh, local, rel)

    for rel in FILES:
        local = PROJECT / rel
        if not local.exists():
            print(f"  [SKIP] {rel}")
            continue
        remote_path = f"{REMOTE}/{rel}".replace("\\", "/")
        remote_dir = os.path.dirname(remote_path)
        ssh.exec_command(f"mkdir -p {remote_dir}")
        sftp.put(str(local), remote_path)
        uploaded += 1
        print(f"  [OK] {rel}")

    sftp.close()
    print(f"\nЗагружено файлов: {uploaded}")

    commands = [
        f"cd {REMOTE} && docker compose up -d postgres redis 2>&1 | tail -10",
        f"cd {REMOTE} && docker compose up -d --build backend nginx 2>&1 | tail -20",
        f"cd {REMOTE} && python3 fix_db_now.py 2>&1 | tail -15 || true",
        f"cd {REMOTE} && docker compose --profile monitoring up -d monitoring 2>&1 | tail -10",
        "sleep 6 && curl -s http://127.0.0.1:8000/health",
        "curl -s http://127.0.0.1:8000/api/pulse/stats | head -c 220",
        "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/map.html",
    ]
    for cmd in commands:
        print(f"\n$ {cmd[:90]}...")
        _, stdout, stderr = ssh.exec_command(cmd, timeout=300)
        out = stdout.read().decode("utf-8", errors="replace").strip()
        err = stderr.read().decode("utf-8", errors="replace").strip()
        if out:
            print(out)
        if err and "warning" not in err.lower():
            print(err)

    ssh.close()
    print("\n" + "=" * 60)
    print("  ДЕПЛОЙ ЗАВЕРШЁН")
    print(f"  http://{HOST}/health")
    print(f"  http://{HOST}/map")
    print("=" * 60)


if __name__ == "__main__":
    main()
