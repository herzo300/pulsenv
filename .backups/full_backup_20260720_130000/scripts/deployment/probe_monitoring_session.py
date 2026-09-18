"""Probe whether monitoring Telethon session is authorized."""

from __future__ import annotations

import asyncio
import os
import sys

import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

load_dotenv(r"C:\Soobshio_project\.env")
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()

PROBE = r'''
import asyncio, os
from services.monitoring.telegram_client_factory import build_monitoring_telegram_client, describe_telegram_transport

async def main():
    path = os.getenv("MONITORING_SESSION_PATH", "/app/session/monitoring_session")
    print("transport", describe_telegram_transport())
    print("session", path)
    client = build_monitoring_telegram_client(path)
    await client.connect()
    try:
        ok = await client.is_user_authorized()
        print("authorized", ok)
        if ok:
            me = await client.get_me()
            print("user", me.id, me.username)
    finally:
        await client.disconnect()

asyncio.run(main())
'''


def main() -> int:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect("45.153.68.59", username="root", password=PASSWORD, timeout=25, look_for_keys=False, allow_agent=False)
    cmd = (
        "cd /root/citypulse_api && docker compose exec -T monitoring "
        "python -c " + repr(PROBE)
    )
    _, stdout, stderr = ssh.exec_command(cmd, timeout=120)
    print(stdout.read().decode("utf-8", errors="replace"))
    err = stderr.read().decode("utf-8", errors="replace").strip()
    if err:
        print(err)
    ssh.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
