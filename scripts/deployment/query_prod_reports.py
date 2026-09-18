"""Query TG reports in prod DB and seed map if needed."""

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

    queries = [
        """docker exec soobshio_postgres psql -U soobshio -d soobshio -t -A -c "
SELECT COUNT(*) FROM reports WHERE source LIKE 'tg:%';" """,
        """docker exec soobshio_postgres psql -U soobshio -d soobshio -t -A -c "
SELECT COUNT(*) FROM reports WHERE source LIKE 'tg:%' AND lat IS NOT NULL AND lng IS NOT NULL;" """,
        """docker exec soobshio_postgres psql -U soobshio -d soobshio -c "
SELECT id, left(title,50) AS title, left(address,40) AS address, lat, lng, category, source
FROM reports
WHERE lat IS NOT NULL AND lng IS NOT NULL
ORDER BY id DESC LIMIT 15;" """,
        """docker exec soobshio_postgres psql -U soobshio -d soobshio -t -A -c "
SELECT COUNT(*) FROM reports;" """,
    ]
    for q in queries:
        print("\n$", q[:80])
        _, stdout, stderr = ssh.exec_command(q, timeout=60)
        print(stdout.read().decode("utf-8", errors="replace"))
        err = stderr.read().decode("utf-8", errors="replace").strip()
        if err:
            print("ERR:", err)

    ssh.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
