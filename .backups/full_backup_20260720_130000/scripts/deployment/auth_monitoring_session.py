#!/usr/bin/env python3
"""Authorize Telethon monitoring session (headless-friendly, two-step)."""

from __future__ import annotations

import argparse
import asyncio
import json
import os
from pathlib import Path

from telethon import TelegramClient, connection
from telethon.errors import SessionPasswordNeededError


def _env_int(name: str) -> int:
    return int(os.getenv(name, "0").strip().strip('"').strip("'"))


def _env_str(name: str) -> str:
    return os.getenv(name, "").strip().strip('"').strip("'")


def _build_client(session_path: str) -> TelegramClient:
    api_id = _env_int("TG_API_ID")
    api_hash = _env_str("TG_API_HASH")
    raw = _env_str("TELEGRAM_MTPROXY")
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


def _auth_state_path(session_path: str) -> Path:
    return Path(f"{session_path}.auth_state.json")


async def _ensure_authorized(
    *,
    session_path: str,
    code: str | None,
    request_only: bool,
) -> int:
    phone = _env_str("TG_PHONE")
    password_2fa = _env_str("TG_2FA_PASSWORD")
    api_id = _env_int("TG_API_ID")
    api_hash = _env_str("TG_API_HASH")

    if not api_id or not api_hash:
        print("ERROR: TG_API_ID / TG_API_HASH are missing")
        return 1
    if not phone:
        print("ERROR: TG_PHONE is missing")
        return 1

    client = _build_client(session_path)
    state_path = _auth_state_path(session_path)
    print(f"mtproxy={bool(_env_str('TELEGRAM_MTPROXY'))}")
    print(f"session={session_path}")
    print(f"phone={phone[:4]}***{phone[-2:]}")

    await client.connect()
    try:
        if await client.is_user_authorized():
            me = await client.get_me()
            print(
                "OK already_authorized",
                f"id={me.id}",
                f"username=@{me.username or '-'}",
            )
            state_path.unlink(missing_ok=True)
            return 0

        if request_only or not code:
            sent = await client.send_code_request(phone)
            payload = {
                "phone": phone,
                "phone_code_hash": sent.phone_code_hash,
            }
            state_path.parent.mkdir(parents=True, exist_ok=True)
            state_path.write_text(
                json.dumps(payload, ensure_ascii=False),
                encoding="utf-8",
            )
            print("OK code_requested")
            print(f"state_file={state_path}")
            print("Next: pass --code <telegram_code>")
            return 2

        if not state_path.exists():
            print("ERROR: auth state missing. Run with --request-code first.")
            return 1

        payload = json.loads(state_path.read_text(encoding="utf-8"))
        phone_code_hash = payload.get("phone_code_hash")
        if not phone_code_hash:
            print("ERROR: phone_code_hash missing in auth state")
            return 1

        try:
            await client.sign_in(
                phone=phone,
                code=code.strip(),
                phone_code_hash=phone_code_hash,
            )
        except SessionPasswordNeededError:
            if not password_2fa:
                print("ERROR: 2FA password required. Set TG_2FA_PASSWORD in .env")
                return 1
            await client.sign_in(password=password_2fa)

        if not await client.is_user_authorized():
            print("ERROR: sign_in finished but session is still unauthorized")
            return 1

        me = await client.get_me()
        print(
            "OK authorized",
            f"id={me.id}",
            f"username=@{me.username or '-'}",
        )
        state_path.unlink(missing_ok=True)
        return 0
    finally:
        await client.disconnect()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    default_session = os.getenv(
        "MONITORING_SESSION_PATH",
        "/app/session/monitoring_session",
    )
    parser.add_argument("--session-path", default=default_session)
    parser.add_argument("--request-code", action="store_true")
    parser.add_argument("--code", default="")
    args = parser.parse_args()

    code = args.code.strip() or None
    request_only = bool(args.request_code) or not code
    return asyncio.run(
        _ensure_authorized(
            session_path=args.session_path,
            code=code,
            request_only=request_only,
        )
    )


if __name__ == "__main__":
    raise SystemExit(main())
