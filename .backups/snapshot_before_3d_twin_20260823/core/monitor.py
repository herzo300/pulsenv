import asyncio
import os
from collections.abc import Sequence

from dotenv import load_dotenv
from telethon import TelegramClient, events

load_dotenv()

DEFAULT_CHANNELS = ("@typical_nv86",)


def _load_monitor_config() -> tuple[int, str]:
    api_id_raw = os.getenv("TG_API_ID", "0").strip()
    api_id = int(api_id_raw) if api_id_raw else 0
    api_hash = os.getenv("TG_API_HASH", "").strip()
    if not api_id or not api_hash:
        raise ValueError("TG_API_ID and TG_API_HASH must be set before monitor startup")
    return api_id, api_hash


def create_client(
    *,
    session_name: str = "soobshio_session",
    channels: Sequence[str] | None = None,
) -> TelegramClient:
    api_id, api_hash = _load_monitor_config()
    client = TelegramClient(session_name, api_id, api_hash)
    register_handlers(client, channels=channels or DEFAULT_CHANNELS)
    return client


def register_handlers(
    client: TelegramClient,
    *,
    channels: Sequence[str] | None = None,
) -> TelegramClient:
    monitored_channels = list(channels or DEFAULT_CHANNELS)

    @client.on(events.NewMessage(chats=monitored_channels))
    async def handler(event):
        from services.data_layer.database import SessionLocal
        from services.data_layer.models import Report
        from core.geoparse import claude_geoparse

        text = event.message.text or ""
        if len(text) < 20:
            return

        complaint_keywords = ["яма", "фонарь", "мусор", "потоп", "дыра"]
        if not any(kw in text.lower() for kw in complaint_keywords):
            return

        print(f"Complaint detected: {text[:100]}...")

        try:
            lat, lng, address = await claude_geoparse(text)
        except Exception as exc:
            print(f"Claude geoparse error: {exc}")
            lat, lng, address = 61.034, 76.553, "Нижневартовск центр"

        db = SessionLocal()
        try:
            report = Report(
                title=f"TG: {address}",
                description=text[:500],
                lat=lat,
                lng=lng,
                category="auto",
            )
            db.add(report)
            db.commit()
            print(f"Saved report #{report.id} {address} [{lat:.4f},{lng:.4f}]")
        finally:
            db.close()

    return client


async def start(*, channels: Sequence[str] | None = None) -> None:
    client = create_client(channels=channels)
    await client.start()  # type: ignore[misc]
    print("Claude monitoring started!")
    await client.run_until_disconnected()  # type: ignore[misc]


if __name__ == "__main__":
    asyncio.run(start())
