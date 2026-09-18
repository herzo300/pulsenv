"""Remote prod diagnostics for DB + map feed."""

from __future__ import annotations

import json
import os
import sys

import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

load_dotenv(r"C:\Soobshio_project\.env")
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()


def run(ssh, cmd, timeout=120):
    print("\n$", cmd[:100])
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    out = o.read().decode("utf-8", errors="replace")
    err = e.read().decode("utf-8", errors="replace")
    if out.strip():
        print(out.strip()[:4000])
    if err.strip():
        print("ERR:", err.strip()[:1500])
    return out


def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect("45.153.68.59", username="root", password=PASSWORD, timeout=25, look_for_keys=False, allow_agent=False)
    run(ssh, "docker ps --format 'table {{.Names}}\t{{.Status}}' | head -10")
    run(ssh, "docker exec soobshio_backend printenv DATABASE_URL | sed 's/:[^:@]*@/:***@/'")
    run(
        ssh,
        "docker exec soobshio_backend python -c \""
        "import os; from sqlalchemy import create_engine,text; "
        "print('url', os.environ.get('DATABASE_URL','')[:40]); "
        "e=create_engine(os.environ['DATABASE_URL']); "
        "c=e.connect(); print('reports', c.execute(text('SELECT count(*) FROM reports')).scalar()); c.close()\"",
    )
    feed = run(ssh, "curl -s 'http://127.0.0.1:8000/api/map/feed?limit=200&layers=all&refresh=1'")
    try:
        d = json.loads(feed)
        m = d.get("markers") or []
        tg = [x for x in m if str(x.get("source", "")).startswith("tg:")]
        print("MAP", json.dumps({"total": len(m), "tg": len(tg), "counts": d.get("counts")}, ensure_ascii=False))
    except Exception as exc:
        print("feed parse", exc)
    ssh.close()


if __name__ == "__main__":
    main()
