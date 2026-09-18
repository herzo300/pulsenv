"""Upload and run fix_db_now.py on production."""

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
    ssh.connect("45.153.68.59", username="root", password=PASSWORD, timeout=25, look_for_keys=False, allow_agent=False)
    sftp = ssh.open_sftp()
    sftp.put(r"c:\Soobshio_project\scripts\deployment\fix_db_now.py", f"{REMOTE}/fix_db_now.py")
    sftp.close()
    _, o, e = ssh.exec_command(f"python3 {REMOTE}/fix_db_now.py", timeout=240)
    print(o.read().decode("utf-8", errors="replace"))
    err = e.read().decode("utf-8", errors="replace")
    if err.strip():
        print("ERR:", err)
    _, feed, _ = ssh.exec_command("curl -s 'http://127.0.0.1/api/map/feed?limit=200&layers=all&refresh=1'", timeout=120)
    raw = feed.read().decode("utf-8", errors="replace")
    try:
        payload = json.loads(raw)
        markers = payload.get("markers") or []
        tg = [m for m in markers if str(m.get("source", "")).startswith("tg:")]
        print(
            "MAP:",
            json.dumps(
                {
                    "total": len(markers),
                    "tg": len(tg),
                    "public_reports": payload.get("counts", {}).get("public_reports"),
                    "events": payload.get("counts", {}).get("events_today"),
                },
                ensure_ascii=False,
            ),
        )
    except json.JSONDecodeError:
        print(raw[:500])
    ssh.close()
    print("health:", httpx.get("http://45.153.68.59/health", timeout=20).text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
