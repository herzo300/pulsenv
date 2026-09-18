#!/usr/bin/env python3
"""
Local Telegram backfill into production PostgreSQL via SSH tunnel.

Requires in .env:
  SSH_PASSWORD          — root password for VPS
  POSTGRES_PASSWORD     — optional fallback if remote .env read fails
  TG_API_ID / TG_API_HASH — for Telethon backfill

Usage (from project root):
  python scripts/maintenance/local_backfill_prod.py --prune --days 30
  python scripts/maintenance/local_backfill_prod.py --prune-only
  python scripts/maintenance/local_backfill_prod.py --days 30 --source auto
"""

from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path
from urllib.parse import quote_plus

import paramiko
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

load_dotenv(ROOT / ".env")

PROD_HOST = os.getenv("PROD_SSH_HOST", "45.153.68.59").strip()
PROD_USER = os.getenv("PROD_SSH_USER", "root").strip()
LOCAL_PORT = int(os.getenv("PROD_DB_LOCAL_PORT", "15432"))
REMOTE_COMPOSE = os.getenv("PROD_COMPOSE_DIR", "/root/citypulse_api").strip()
POSTGRES_CONTAINER = os.getenv("PROD_POSTGRES_CONTAINER", "soobshio_postgres").strip()


def _relay(source: socket.socket, dest) -> None:
    def _forward(reader, writer) -> None:
        try:
            while True:
                data = reader.recv(65536)
                if not data:
                    break
                writer.sendall(data)
        except OSError:
            pass
        finally:
            try:
                writer.shutdown(socket.SHUT_WR)
            except OSError:
                pass

    t1 = threading.Thread(target=_forward, args=(source, dest), daemon=True)
    t2 = threading.Thread(target=_forward, args=(dest, source), daemon=True)
    t1.start()
    t2.start()
    t1.join()
    t2.join()
    for sock in (source, dest):
        try:
            sock.close()
        except OSError:
            pass


class SshTunnel:
    """Local TCP port -> remote docker postgres via SSH direct-tcpip."""

    def __init__(
        self,
        *,
        ssh_host: str,
        ssh_user: str,
        ssh_password: str,
        remote_pg_host: str,
        remote_pg_port: int = 5432,
        local_port: int = 15432,
    ) -> None:
        self._local_port = local_port
        self._remote_pg_host = remote_pg_host
        self._remote_pg_port = remote_pg_port
        self._stop = threading.Event()
        self._server: socket.socket | None = None
        self._thread: threading.Thread | None = None
        self._client = paramiko.SSHClient()
        self._client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self._client.connect(
            ssh_host,
            username=ssh_user,
            password=ssh_password,
            timeout=25,
            look_for_keys=False,
            allow_agent=False,
        )
        self._transport = self._client.get_transport()
        if self._transport is None:
            raise RuntimeError("SSH transport unavailable")

    def start(self) -> None:
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", self._local_port))
        server.listen(32)
        server.settimeout(1.0)
        self._server = server

        def _serve() -> None:
            assert self._server is not None
            while not self._stop.is_set():
                try:
                    client_sock, client_addr = self._server.accept()
                except socket.timeout:
                    continue
                except OSError:
                    break
                try:
                    channel = self._transport.open_channel(
                        "direct-tcpip",
                        (self._remote_pg_host, self._remote_pg_port),
                        client_addr,
                    )
                except Exception:
                    client_sock.close()
                    continue
                threading.Thread(
                    target=_relay,
                    args=(client_sock, channel),
                    daemon=True,
                ).start()

        self._thread = threading.Thread(target=_serve, daemon=True)
        self._thread.start()
        self._wait_until_ready()

    def _wait_until_ready(self, timeout: float = 20.0) -> None:
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                with socket.create_connection(("127.0.0.1", self._local_port), 2):
                    return
            except OSError:
                time.sleep(0.3)
        raise TimeoutError(f"SSH tunnel did not open on 127.0.0.1:{self._local_port}")

    def close(self) -> None:
        self._stop.set()
        if self._server is not None:
            try:
                self._server.close()
            except OSError:
                pass
        self._client.close()


def _ssh_exec(ssh: paramiko.SSHClient, command: str) -> str:
    _, stdout, stderr = ssh.exec_command(command, timeout=60)
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    code = stdout.channel.recv_exit_status()
    if code != 0:
        raise RuntimeError(err or out or f"remote command failed: {command}")
    return out


def _fetch_remote_pg_password(ssh: paramiko.SSHClient) -> str:
    script = (
        "python3 - <<'PY'\n"
        "from pathlib import Path\n"
        "text = Path('/root/citypulse_api/.env').read_text(encoding='utf-8')\n"
        "for line in text.splitlines():\n"
        "    if line.startswith('POSTGRES_PASSWORD='):\n"
        "        print(line.split('=', 1)[1].strip().strip('\"').strip(\"'\"))\n"
        "        break\n"
        "PY"
    )
    return _ssh_exec(ssh, script)


def _fetch_postgres_ip(ssh: paramiko.SSHClient) -> str:
    cmd = (
        f"docker inspect {POSTGRES_CONTAINER} "
        "--format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'"
    )
    ip = _ssh_exec(ssh, cmd)
    if not ip:
        raise RuntimeError(f"Could not resolve IP for {POSTGRES_CONTAINER}")
    return ip


def _run_child(script: Path, env: dict[str, str], extra_args: list[str]) -> int:
    proc = subprocess.run(
        [sys.executable, str(script), *extra_args],
        cwd=str(ROOT),
        env=env,
        check=False,
    )
    return proc.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="Local TG backfill via SSH tunnel")
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--limit-per-channel", type=int, default=500)
    parser.add_argument(
        "--source",
        choices=("auto", "telethon", "web"),
        default="auto",
    )
    parser.add_argument(
        "--prune",
        action="store_true",
        help="Delete reports without coordinates before backfill.",
    )
    parser.add_argument(
        "--prune-only",
        action="store_true",
        help="Only prune reports without coordinates.",
    )
    parser.add_argument("--local-port", type=int, default=LOCAL_PORT)
    parser.add_argument(
        "--proxy",
        default=os.getenv("TELEGRAM_PROXY", "").strip() or None,
        help="SOCKS/HTTP proxy URL (optional).",
    )
    parser.add_argument(
        "--mtproxy",
        default=os.getenv("TELEGRAM_MTPROXY", "").strip() or None,
        help="Telegram MTProxy host:port:hexsecret — works without VPN app.",
    )
    args = parser.parse_args()

    if args.mtproxy:
        os.environ["TELEGRAM_MTPROXY"] = args.mtproxy
        print(f"Telegram MTProxy: {args.mtproxy.split(':')[0]}:{args.mtproxy.split(':')[1]}")
    if args.proxy:
        os.environ["TELEGRAM_PROXY"] = args.proxy
        print(f"Telegram proxy: {args.proxy.split('@')[-1]}")
    if not args.mtproxy and not args.proxy and not (os.getenv("TELEGRAM_PROXY") or os.getenv("TELEGRAM_MTPROXY")):
        print(
            "Hint: if Telegram is blocked, try MTProxy (not VPN): "
            "python scripts/maintenance/check_telegram_access.py"
        )

    ssh_password = os.getenv("SSH_PASSWORD", "").strip()
    if not ssh_password:
        print("[ERROR] SSH_PASSWORD missing in .env", file=sys.stderr)
        return 1

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(
        PROD_HOST,
        username=PROD_USER,
        password=ssh_password,
        timeout=25,
        look_for_keys=False,
        allow_agent=False,
    )

    try:
        pg_password = _fetch_remote_pg_password(ssh)
        pg_ip = _fetch_postgres_ip(ssh)
    finally:
        ssh.close()

    if not pg_password:
        pg_password = os.getenv("POSTGRES_PASSWORD", "").strip()
    if not pg_password:
        print("[ERROR] Could not resolve postgres password", file=sys.stderr)
        return 1

    db_url = (
        f"postgresql+psycopg2://soobshio:{quote_plus(pg_password)}"
        f"@127.0.0.1:{args.local_port}/soobshio"
    )
    child_env = os.environ.copy()
    child_env["DATABASE_URL"] = db_url

    tunnel = SshTunnel(
        ssh_host=PROD_HOST,
        ssh_user=PROD_USER,
        ssh_password=ssh_password,
        remote_pg_host=pg_ip,
        local_port=args.local_port,
    )

    print(
        f"SSH tunnel 127.0.0.1:{args.local_port} -> {pg_ip}:5432 via {PROD_HOST}"
    )
    try:
        tunnel.start()
        prune_script = ROOT / "scripts" / "maintenance" / "prune_reports_without_coords.py"
        backfill_script = ROOT / "scripts" / "maintenance" / "backfill_telegram_last_days.py"

        if args.prune or args.prune_only:
            print("\n--- Prune reports without coordinates ---")
            code = _run_child(
                prune_script,
                child_env,
                ["--apply"],
            )
            if code != 0:
                return code

        if args.prune_only:
            return 0

        print("\n--- Telegram backfill ---")
        return _run_child(
            backfill_script,
            child_env,
            [
                "--days",
                str(args.days),
                "--limit-per-channel",
                str(args.limit_per_channel),
                "--source",
                args.source,
            ],
        )
    finally:
        tunnel.close()


if __name__ == "__main__":
    raise SystemExit(main())
