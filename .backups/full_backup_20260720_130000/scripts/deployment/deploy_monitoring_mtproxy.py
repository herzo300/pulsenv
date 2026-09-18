#!/usr/bin/env python3
"""Deploy VK fix + MTProxy for monitoring on production."""

from __future__ import annotations

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

load_dotenv(PROJECT / ".env")
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()

# Public MTProxy candidates (host:port:hexsecret). Probed on VPS; first working wins.
MTPROXY_CANDIDATES = [
    "87.248.129.192:443:ee1603010200010001fc030386e24c3add626973636f7474692e79656b74616e65742e636f6d",
    "87.248.129.191:443:ee1603010200010001fc030386e24c3add626973636f7474692e79656b74616e65742e636f6d",
    "87.248.129.190:443:ee1603010200010001fc030386e24c3add626973636f7474692e79656b74616e65742e636f6d",
    "87.248.129.189:4455:ee1603010200010001fc030386e24c3add626973636f7474692e79656b74616e65742e636f6d",
    "87.248.129.194:443:ee1603010200010001fc030386e24c3add626973636f7474692e79656b74616e65742e636f6d",
    "87.248.129.195:443:ee1603010200010001fc030386e24c3add626973636f7474692e79656b74616e65742e636f6d",
    "87.248.129.196:443:ee1603010200010001fc030386e24c3add626973636f7474692e79656b74616e65742e636f6d",
    "87.248.129.193:443:ee1603010200010001fc030386e24c3add626973636f7474692e79656b74616e65742e636f6d",
]

PROBE_SCRIPT = r'''#!/usr/bin/env python3
import asyncio
import os
import sys

sys.path.insert(0, "/app")
os.chdir("/app")

from dotenv import load_dotenv
load_dotenv("/app/.env")

from services.monitoring.config import API_ID, API_HASH
from services.monitoring.telegram_client_factory import build_monitoring_telegram_client

async def probe(mtproxy: str) -> bool:
    os.environ["TELEGRAM_MTPROXY"] = mtproxy
    os.environ.pop("TELEGRAM_PROXY", None)
    client = build_monitoring_telegram_client("/tmp/mtproxy_probe")
    try:
        await asyncio.wait_for(client.connect(), timeout=20)
        ok = client.is_connected()
        return ok
    except Exception as exc:
        print("fail", mtproxy.split(":")[0], str(exc)[:120], flush=True)
        return False
    finally:
        await client.disconnect()

async def main():
    candidates = sys.argv[1:]
    for item in candidates:
        host = item.split(":")[0]
        print("try", host, flush=True)
        if await probe(item):
            print("OK", item, flush=True)
            return
    print("NONE", flush=True)

asyncio.run(main())
'''

ENV_PATCH_SCRIPT = r'''#!/usr/bin/env python3
import sys
from pathlib import Path

root = Path("/root/citypulse_api")
env_path = root / ".env"
mtproxy = sys.argv[1].strip()
lines = []
found = False
for line in env_path.read_text(encoding="utf-8").splitlines():
    if line.startswith("TELEGRAM_MTPROXY="):
        lines.append(f"TELEGRAM_MTPROXY={mtproxy}")
        found = True
    else:
        lines.append(line)
if not found:
    lines.append(f"TELEGRAM_MTPROXY={mtproxy}")
env_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("env_updated", mtproxy.split(":")[0])
'''


def sync_monitoring(sftp, ssh) -> int:
    uploaded = 0
    local_base = PROJECT / "services" / "monitoring"
    remote_base = f"{REMOTE}/services/monitoring"
    for root, dirs, files in os.walk(local_base):
        dirs[:] = [d for d in dirs if d != "__pycache__"]
        rel = Path(root).relative_to(local_base)
        remote_dir = remote_base if str(rel) == "." else f"{remote_base}/{rel.as_posix()}"
        try:
            sftp.stat(remote_dir)
        except OSError:
            ssh.exec_command(f"mkdir -p {remote_dir}")
        for name in files:
            if name.endswith((".pyc", ".pyo")):
                continue
            lp = Path(root) / name
            rp = f"{remote_dir}/{name}"
            sftp.put(str(lp), rp)
            uploaded += 1
            print(f"  [OK] services/monitoring/{rel.as_posix()}/{name}".replace("/./", "/"))
    for rel in ("start_all_monitoring.py", "services/vk_monitor_service.py"):
        local = PROJECT / rel
        if local.exists():
            remote = f"{REMOTE}/{rel}".replace("\\", "/")
            ssh.exec_command(f"mkdir -p {os.path.dirname(remote)}")
            sftp.put(str(local), remote)
            uploaded += 1
            print(f"  [OK] {rel}")
    return uploaded


def run(ssh, cmd: str, timeout: int = 300) -> str:
    print(f"\n$ {cmd[:120]}")
    _, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace").strip()
    if out.strip():
        print(out.rstrip())
    if err and "warning" not in err.lower():
        print("ERR:", err[:500])
    return out


def main() -> int:
    if not PASSWORD:
        print("SSH_PASSWORD missing")
        return 1

    local_mtproxy = (os.getenv("TELEGRAM_MTPROXY") or "").strip()
    candidates = [local_mtproxy] if local_mtproxy else []
    candidates.extend(MTPROXY_CANDIDATES)

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASSWORD, timeout=25, look_for_keys=False, allow_agent=False)
    sftp = ssh.open_sftp()

    print("=" * 60)
    print("Deploy monitoring: VK fix + MTProxy")
    print("=" * 60)

    uploaded = sync_monitoring(sftp, ssh)
    print(f"Uploaded {uploaded} files")

    sftp.putfo(__import__("io").BytesIO(PROBE_SCRIPT.encode()), f"{REMOTE}/probe_mtproxy.py")
    sftp.putfo(__import__("io").BytesIO(ENV_PATCH_SCRIPT.encode()), f"{REMOTE}/patch_mtproxy_env.py")
    sftp.close()

    run(ssh, f"chmod +x {REMOTE}/probe_mtproxy.py {REMOTE}/patch_mtproxy_env.py")

    # Rebuild monitoring image so new code is inside container
    run(
        ssh,
        f"cd {REMOTE} && docker compose --profile monitoring build monitoring 2>&1 | tail -15",
        timeout=600,
    )

    chosen = local_mtproxy
    if not chosen:
        quoted = " ".join(repr(c) for c in MTPROXY_CANDIDATES[:5])
        probe_out = run(
            ssh,
            f"cd {REMOTE} && docker compose --profile monitoring run --rm -T "
            f"-v {REMOTE}/probe_mtproxy.py:/tmp/probe_mtproxy.py:ro monitoring "
            f"python /tmp/probe_mtproxy.py {quoted} 2>&1",
            timeout=300,
        )
        for line in probe_out.splitlines():
            if line.startswith("OK "):
                chosen = line[3:].strip()
                break

    if not chosen:
        print("\n[WARN] No working MTProxy found from candidates.")
        print("Set TELEGRAM_MTPROXY in local .env and re-run, or add proxy manually on server.")
    else:
        print(f"\nUsing MTProxy: {chosen.split(':')[0]}:{chosen.split(':')[1]}")
        run(ssh, f"python3 {REMOTE}/patch_mtproxy_env.py {chosen}")

    run(
        ssh,
        f"cd {REMOTE} && docker compose --profile monitoring up -d --force-recreate monitoring 2>&1 | tail -10",
        timeout=180,
    )
    print("Waiting for monitoring startup...")
    time.sleep(18)

    logs = run(ssh, "docker logs soobshio_monitoring --tail 35 2>&1")
    ok_signals = [
        "Telegram transport: MTProxy",
        "Telegram подключён",
        "VK polling started",
    ]
    bad_signals = ["timedelta", "Telegram is blocked", "not authorized"]

    for sig in ok_signals:
        if sig.lower() in logs.lower():
            print(f"[OK] log contains: {sig}")
    for sig in bad_signals:
        if sig.lower() in logs.lower():
            print(f"[WARN] log contains: {sig}")

    run(ssh, "docker logs soobshio_monitoring 2>&1 | grep -E 'timedelta|VK poll error' | tail -5 || echo vk_errors:none")

    ssh.close()
    print("\n" + "=" * 60)
    print("Monitoring deploy finished")
    print("=" * 60)
    return 0 if chosen else 1


if __name__ == "__main__":
    raise SystemExit(main())
