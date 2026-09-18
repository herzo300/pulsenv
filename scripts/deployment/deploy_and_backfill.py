"""Deploy backend + run Telegram backfill + verify map markers on production."""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT = Path(r"C:\Soobshio_project")
HOST = "45.153.68.59"
USER = "root"
REMOTE = "/root/citypulse_api"
BACKEND = "soobshio_backend"

load_dotenv(PROJECT / ".env")
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()
if not PASSWORD:
    print("[ERROR] SSH_PASSWORD missing in .env")
    sys.exit(1)


def run_ssh(ssh: paramiko.SSHClient, cmd: str, *, timeout: int = 600) -> tuple[int, str, str]:
    print(f"\n$ {cmd[:120]}...")
    _, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    code = stdout.channel.recv_exit_status()
    if out:
        print(out)
    if err and code != 0:
        print(err)
    return code, out, err


def main() -> int:
    print("=" * 60)
    print("  Deploy + TG backfill + map marker verify")
    print("=" * 60)

    # Step 1: sync & rebuild via existing deploy script
    deploy_script = PROJECT / "scripts" / "deployment" / "deploy_improvements.py"
    code = os.spawnv(os.P_WAIT, sys.executable, [sys.executable, str(deploy_script)])
    if code != 0:
        print(f"[WARN] deploy_improvements exited with {code}")

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

    # Step 2: ensure backfill script path inside container
    run_ssh(
        ssh,
        f"docker exec {BACKEND} mkdir -p /app/scripts/maintenance",
    )
    sftp = ssh.open_sftp()
    local_backfill = PROJECT / "scripts" / "maintenance" / "backfill_telegram_last_days.py"
    remote_backfill = f"{REMOTE}/scripts/maintenance/backfill_telegram_last_days.py"
    sftp.put(str(local_backfill), remote_backfill)
    sftp.close()
    run_ssh(
        ssh,
        f"docker cp {remote_backfill} {BACKEND}:/app/scripts/maintenance/backfill_telegram_last_days.py",
    )

    # Step 3: backfill 30 days (web first, telethon fallback inside script)
    print("\n--- Telegram backfill (30 days) ---")
    code, out, _ = run_ssh(
        ssh,
        (
            f"docker exec -w /app {BACKEND} "
            f"python scripts/maintenance/backfill_telegram_last_days.py "
            f"--days 30 --limit-per-channel 500 --source auto"
        ),
        timeout=900,
    )
    if code != 0:
        print(f"[WARN] backfill exit code {code}")

    # Step 4: restart backend to clear map feed cache
    run_ssh(ssh, f"cd {REMOTE} && docker compose restart backend 2>&1 | tail -5")
    time.sleep(8)

    # Step 5: verify map feed
    print("\n--- Map feed verification ---")
    _, feed_raw, _ = run_ssh(
        ssh,
        "curl -s 'http://127.0.0.1:8000/api/map/feed?limit=120&layers=all'",
        timeout=60,
    )
    try:
        feed = json.loads(feed_raw)
        markers = feed.get("markers") or []
        events = [
            m
            for m in markers
            if m.get("source_kind") == "event"
            or str(m.get("category") or "") == "Мероприятие"
        ]
        tg_markers = [
            m
            for m in markers
            if str(m.get("source") or "").lower().startswith("tg:")
        ]
        print(
            json.dumps(
                {
                    "total_markers": len(markers),
                    "event_markers": len(events),
                    "tg_markers": len(tg_markers),
                    "counts": feed.get("counts"),
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    except json.JSONDecodeError:
        print("[WARN] Could not parse map feed JSON")
        print(feed_raw[:500])

    _, public_feed, _ = run_ssh(
        ssh,
        f"curl -s 'http://127.0.0.1/api/map/feed?limit=80&layers=all' | head -c 400",
    )

    run_ssh(ssh, "curl -s http://127.0.0.1:8000/health")
    ssh.close()

    print("\n" + "=" * 60)
    print(f"  Done: http://{HOST}/map")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
