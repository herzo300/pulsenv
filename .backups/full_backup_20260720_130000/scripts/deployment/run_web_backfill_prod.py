"""Run TG web backfill on production and verify map markers."""

from __future__ import annotations

import json
import os
import sys
import time

import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

HOST = "45.153.68.59"
REMOTE = "/root/citypulse_api"
BACKEND = "soobshio_backend"

load_dotenv(r"C:\Soobshio_project\.env")
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()


def run(ssh: paramiko.SSHClient, cmd: str, timeout: int = 900) -> tuple[int, str]:
    print(f"\n$ {cmd[:140]}")
    _, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    code = stdout.channel.recv_exit_status()
    if out.strip():
        print(out.strip()[-4000:])
    if err.strip() and code != 0:
        print(err.strip()[-2000:])
    return code, out


def main() -> int:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username="root", password=PASSWORD, timeout=25, look_for_keys=False, allow_agent=False)

    run(
        ssh,
        (
            f"docker exec -w /app {BACKEND} "
            "python scripts/maintenance/backfill_telegram_last_days.py "
            "--days 30 --limit-per-channel 500 --source web"
        ),
        timeout=900,
    )

    run(ssh, f"cd {REMOTE} && docker compose restart backend")
    time.sleep(10)

    _, feed = run(
        ssh,
        "curl -s 'http://127.0.0.1:8000/api/map/feed?limit=200&layers=all&refresh=1'",
    )
    try:
        payload = json.loads(feed)
        markers = payload.get("markers") or []
        tg = [m for m in markers if str(m.get("source", "")).startswith("tg:")]
        events = [
            m
            for m in markers
            if m.get("source_kind") == "event"
            or m.get("category") == "Мероприятие"
        ]
        print("\nSUMMARY:", json.dumps({
            "total": len(markers),
            "tg": len(tg),
            "events": len(events),
            "counts": payload.get("counts"),
            "sample_tg": [
                {"id": m.get("id"), "summary": (m.get("summary") or "")[:80], "address": m.get("address")}
                for m in tg[:5]
            ],
        }, ensure_ascii=False, indent=2))
    except Exception as exc:
        print("parse error", exc)

    run(
        ssh,
        (
            f"docker exec {BACKEND} python -c \""
            "from services.data_layer.database import SessionLocal;"
            "from services.data_layer.models import Report;"
            "db=SessionLocal();"
            "q=db.query(Report).filter(Report.source.like('tg:%'), Report.lat.isnot(None));"
            "print('tg_with_coords', q.count());"
            "print('tg_events', q.filter(Report.category=='Мероприятие').count());"
            "db.close()\""
        ),
    )
    ssh.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
