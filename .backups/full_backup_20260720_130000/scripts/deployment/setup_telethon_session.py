#!/usr/bin/env python3
"""Deploy monitoring, MTProxy, session file and verify Telegram auth."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

import httpx
import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT = Path(r"C:\Soobshio_project")
REMOTE = "/root/citypulse_api"
HOST = "45.153.68.59"

load_dotenv(PROJECT / ".env")
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()
LOGIN_CODE = os.getenv("TG_LOGIN_CODE", "").strip()

PROBE_SESSION = r'''#!/usr/bin/env python3
import asyncio
import os
from pathlib import Path

from telethon import TelegramClient, connection


def _client(session_path: str) -> TelegramClient:
    api_id = int(os.environ["TG_API_ID"])
    api_hash = os.environ["TG_API_HASH"]
    raw = (os.getenv("TELEGRAM_MTPROXY") or "").strip()
    if raw:
        host, port, secret_str = raw.split(":", 2)
        return TelegramClient(
            session_path,
            api_id,
            api_hash,
            connection=connection.ConnectionTcpMTProxyRandomizedIntermediate,
            proxy=(host, int(port), secret_str),
        )
    return TelegramClient(session_path, api_id, api_hash)


async def main() -> None:
    session = os.getenv("MONITORING_SESSION_PATH", "/app/session/monitoring_session")
    print("session_path", session)
    print("session_file_exists", Path(f"{session}.session").exists())
    print("mtproxy", bool(os.getenv("TELEGRAM_MTPROXY")))
    client = _client(session)
    await client.connect()
    try:
        ok = await client.is_user_authorized()
        print("authorized", ok)
        if ok:
            me = await client.get_me()
            print("user_id", me.id)
            print("username", me.username or "")
    finally:
        await client.disconnect()


asyncio.run(main())
'''


def ssh_run(ssh: paramiko.SSHClient, cmd: str, timeout: int = 300) -> str:
    print(f"\n$ {cmd[:140]}")
    _, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace").strip()
    if out.strip():
        print(out.rstrip())
    if err and "warning" not in err.lower():
        print("ERR:", err[:800])
    stdout.channel.recv_exit_status()
    return out


def main() -> int:
    if not PASSWORD:
        print("ERROR: SSH_PASSWORD missing")
        return 1

    # 1) Rebuild monitoring + MTProxy via existing deploy script
    deploy = PROJECT / "scripts" / "deployment" / "deploy_monitoring_mtproxy.py"
    print("== Step 1: deploy monitoring + MTProxy ==")
    result = subprocess.run(
        [sys.executable, str(deploy)],
        cwd=str(PROJECT),
        timeout=900,
    )
    if result.returncode != 0:
        print("WARN: deploy_monitoring_mtproxy returned", result.returncode)

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username="root", password=PASSWORD, timeout=25, look_for_keys=False, allow_agent=False)

    print("\n== Step 2: normalize session files on host ==")
    ssh_run(
        ssh,
        f"mkdir -p {REMOTE}/session && "
        f"if [ -f {REMOTE}/monitoring_session.session ]; then "
        f"cp -f {REMOTE}/monitoring_session.session {REMOTE}/session/monitoring_session.session; fi && "
        f"if [ -f {REMOTE}/session/monitoring_session.session ]; then "
        f"cp -f {REMOTE}/session/monitoring_session.session {REMOTE}/monitoring_session.session; fi && "
        f"chown -R 1000:1000 {REMOTE}/session && "
        f"chmod -R 777 {REMOTE}/session && "
        f"ls -la {REMOTE}/session/monitoring_session.session {REMOTE}/monitoring_session.session",
    )

    print("\n== Step 3: probe Telethon session in monitoring container ==")
    sftp = ssh.open_sftp()
    sftp.putfo(__import__("io").BytesIO(PROBE_SESSION.encode()), f"{REMOTE}/probe_tg_session.py")
    sftp.put(
        str(PROJECT / "scripts" / "deployment" / "auth_monitoring_session.py"),
        f"{REMOTE}/scripts/deployment/auth_monitoring_session.py",
    )
    sftp.close()

    probe_out = ssh_run(
        ssh,
        f"docker cp {REMOTE}/probe_tg_session.py soobshio_monitoring:/app/probe_tg_session.py && "
        f"docker exec soobshio_monitoring python /app/probe_tg_session.py",
        timeout=120,
    )

    if "authorized True" in probe_out.replace("authorized", "authorized "):
        # handle "authorized True" vs "authorized\nTrue"
        pass

    authorized = "authorized True" in probe_out or "\nauthorized True\n" in f"\n{probe_out}\n"

    if not authorized and "authorized\nTrue" not in probe_out:
        # Telethon prints "authorized True" on one line
        authorized = any(
            line.strip() == "authorized True" for line in probe_out.splitlines()
        )

    if authorized:
        print("\nOK: session already authorized")
    else:
        print("\n== Step 4: request Telegram login code ==")
        auth_cmd = (
            f"cd {REMOTE} && docker compose --profile monitoring run --rm --no-deps "
            f"-v {REMOTE}/session:/app/session "
            f"-v {REMOTE}/scripts/deployment/auth_monitoring_session.py:/app/auth_monitoring_session.py "
            f"monitoring python /app/auth_monitoring_session.py "
            f"--session-path /app/session/monitoring_session"
        )
        if LOGIN_CODE:
            out = ssh_run(ssh, f"{auth_cmd} --code {LOGIN_CODE}", timeout=180)
            if "OK authorized" not in out:
                print("ERROR: authorization failed")
                ssh.close()
                return 1
        else:
            out = ssh_run(ssh, f"{auth_cmd} --request-code", timeout=180)
            if "OK code_requested" in out:
                print(
                    "\nКод отправлен на TG_PHONE.\n"
                    "Добавьте в .env: TG_LOGIN_CODE=XXXXX\n"
                    "И запустите снова: python scripts/deployment/setup_telethon_session.py"
                )
                ssh.close()
                return 0
            print("ERROR: could not request code")
            ssh.close()
            return 1

    print("\n== Step 5: restart monitoring ==")
    ssh_run(
        ssh,
        f"chown -R 1000:1000 {REMOTE}/session && "
        f"chmod -R 777 {REMOTE}/session && "
        f"cd {REMOTE} && docker compose --profile monitoring up -d --force-recreate monitoring 2>&1 | tail -8",
    )
    time.sleep(12)
    logs = ssh_run(ssh, "docker logs soobshio_monitoring --tail 25 2>&1")
    ssh.close()

    status = httpx.get(f"http://{HOST}/api/runtime/monitoring-status", timeout=20).json()
    print(
        "\nmonitoring-status:",
        json.dumps(
            {
                "telegram_ready": status.get("telegram_ready"),
                "telegram_session_ready": status.get("telegram_session_ready"),
                "sessions": status.get("sessions"),
            },
            ensure_ascii=False,
            indent=2,
        ),
    )

    ok = "Telegram подключён" in logs or "✅ Telegram" in logs
    if ok:
        print("\nDONE: Telegram monitoring connected")
        return 0
    print("\nWARN: restart done, check logs for Telegram connection")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
