#!/usr/bin/env python3
import asyncio
import os

from services.monitoring.telegram_client_factory import (
    build_monitoring_telegram_client,
    describe_telegram_transport,
)


async def main() -> None:
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


if __name__ == "__main__":
    asyncio.run(main())
