"""Upload auth script and run Telethon session auth on production."""

from __future__ import annotations

import json
import os
import sys

import httpx
import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT = r"C:\Soobshio_project"
REMOTE = "/root/citypulse_api"
HOST = "45.153.68.59"

load_dotenv(os.path.join(PROJECT, ".env"))
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()
LOGIN_CODE = os.getenv("TG_LOGIN_CODE", "").strip()


def run_remote(ssh: paramiko.SSHClient, cmd: str, timeout: int = 180) -> tuple[int, str, str]:
    print(f"\n$ {cmd}")
    _, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    if out:
        print(out)
    if err:
        print(err)
    exit_status = stdout.channel.recv_exit_status()
    return exit_status, out, err


def main() -> int:
    if not PASSWORD:
        print("ERROR: SSH_PASSWORD missing in .env")
        return 1

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(
        HOST,
        username="root",
        password=PASSWORD,
        timeout=25,
        look_for_keys=False,
        allow_agent=False,
    )
    sftp = ssh.open_sftp()
    local_script = os.path.join(
        PROJECT, "scripts", "deployment", "auth_monitoring_session.py"
    )
    remote_script = f"{REMOTE}/scripts/deployment/auth_monitoring_session.py"
    sftp.put(local_script, remote_script)
    sftp.close()

    run_remote(
        ssh,
        f"mkdir -p {REMOTE}/session && ls -la {REMOTE}/session {REMOTE}/monitoring_session.session 2>/dev/null || true",
    )

    session_path = "/app/session/monitoring_session"
    base_cmd = (
        f"cd {REMOTE} && docker compose --profile monitoring run --rm --no-deps "
        f"-v {REMOTE}/session:/app/session "
        f"-v {REMOTE}/scripts/deployment/auth_monitoring_session.py:/app/scripts/deployment/auth_monitoring_session.py "
        f"monitoring python scripts/deployment/auth_monitoring_session.py "
        f"--session-path {session_path}"
    )

    if LOGIN_CODE:
        code, out, _ = run_remote(ssh, f"{base_cmd} --code {LOGIN_CODE}")
    else:
        code, out, _ = run_remote(ssh, f"{base_cmd} --request-code")
        if code == 2:
            print(
                "\nКод отправлен в Telegram/SMS на TG_PHONE.\n"
                "Добавьте в .env: TG_LOGIN_CODE=12345 и запустите снова:\n"
                "  python scripts/deployment/run_auth_monitoring_session.py"
            )
            ssh.close()
            return 0
        if code != 0:
            ssh.close()
            return code

    if code == 0:
        run_remote(
            ssh,
            f"cd {REMOTE} && docker compose restart monitoring 2>&1 | tail -8",
        )
        run_remote(ssh, "sleep 5 && docker logs soobshio_monitoring --tail 20 2>&1")

    ssh.close()

    status = httpx.get(
        f"http://{HOST}/api/runtime/monitoring-status",
        timeout=20,
    ).json()
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
    return 0 if code == 0 else code


if __name__ == "__main__":
    raise SystemExit(main())
