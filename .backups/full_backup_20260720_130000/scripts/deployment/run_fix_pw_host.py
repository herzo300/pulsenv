"""Upload fix_pw_host.py and run on production."""

from __future__ import annotations

import json
import os
import sys
import time

import httpx
import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

load_dotenv(r"C:\Soobshio_project\.env")
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()

HOST_SCRIPT = r'''#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote_plus

root = Path("/root/citypulse_api")
text = (root / ".env").read_text(encoding="utf-8")
pg = ""
for line in text.splitlines():
    if line.startswith("POSTGRES_PASSWORD="):
        pg = line.split("=", 1)[1].strip().strip('"').strip("'")
        break
if not pg:
    print("no POSTGRES_PASSWORD")
    sys.exit(1)
print("pg_len", len(pg))

db_url = f"postgresql+psycopg2://soobshio:{quote_plus(pg)}@postgres:5432/soobshio"
lines = []
for line in text.splitlines():
    if line.startswith("DATABASE_URL="):
        lines.append("DATABASE_URL=" + db_url)
    else:
        lines.append(line)
(root / ".env").write_text("\n".join(lines) + "\n", encoding="utf-8")

escaped = pg.replace("'", "''")
subprocess.run(
    [
        "docker", "compose", "exec", "-T", "postgres", "psql", "-U", "soobshio", "-d", "postgres",
        "-v", "ON_ERROR_STOP=1", "-c", f"ALTER USER soobshio WITH PASSWORD '{escaped}';",
    ],
    cwd=str(root),
    check=True,
)
print("alter_ok")

subprocess.run(
    ["docker", "compose", "up", "-d", "--no-deps", "--force-recreate", "backend"],
    cwd=str(root),
    check=True,
)
print("backend_recreated")
'''

VERIFY = r'''#!/usr/bin/env python3
import os, time, subprocess, sys
time.sleep(14)
test = subprocess.run(
    [
        "docker", "compose", "exec", "-T", "backend", "python", "-c",
        "import os; from sqlalchemy import create_engine,text; "
        "e=create_engine(os.environ['DATABASE_URL']); "
        "c=e.connect(); print('reports', c.execute(text('SELECT count(*) FROM reports')).scalar()); c.close()",
    ],
    cwd="/root/citypulse_api",
    capture_output=True,
    text=True,
)
print(test.stdout.strip())
if test.returncode:
    print(test.stderr[-3000:], file=sys.stderr)
    sys.exit(test.returncode)
'''


def main() -> int:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect("45.153.68.59", username="root", password=PASSWORD, timeout=25, look_for_keys=False, allow_agent=False)
    sftp = ssh.open_sftp()
    with sftp.open("/root/fix_pw_host.py", "w") as handle:
        handle.write(HOST_SCRIPT)
    with sftp.open("/root/verify_db.py", "w") as handle:
        handle.write(VERIFY)
    sftp.close()

    for cmd in ("python3 /root/fix_pw_host.py", "python3 /root/verify_db.py"):
        print("\n===", cmd)
        _, o, e = ssh.exec_command(cmd, timeout=240)
        print(o.read().decode("utf-8", errors="replace"))
        err = e.read().decode("utf-8", errors="replace").strip()
        if err:
            print("ERR:", err[:3000])

    _, feed, _ = ssh.exec_command(
        "curl -s 'http://127.0.0.1/api/map/feed?limit=200&layers=all&refresh=1'", timeout=120
    )
    raw = feed.read().decode("utf-8", errors="replace")
    try:
        payload = json.loads(raw)
        markers = payload.get("markers") or []
        tg = [m for m in markers if str(m.get("source", "")).startswith("tg:")]
        print(
            "MAP:",
            json.dumps(
                {"total": len(markers), "tg": len(tg), "counts": payload.get("counts")},
                ensure_ascii=False,
            ),
        )
    except json.JSONDecodeError:
        print(raw[:400])

    ssh.close()
    print("health:", httpx.get("http://45.153.68.59/health", timeout=20).text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
