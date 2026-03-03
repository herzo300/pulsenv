import asyncio
import os
from telethon import TelegramClient, events
from dotenv import load_dotenv

load_dotenv()

_api_id_str = os.getenv('TG_API_ID', '0')
api_id = int(_api_id_str) if _api_id_str else 0
api_hash = os.getenv('TG_API_HASH', '')
CHANNELS = ['@typical_nv86']

if not api_id or not api_hash:
    raise ValueError("TG_API_ID and TG_API_HASH must be set in .env")

client = TelegramClient('soobshio_session', api_id, api_hash)


@client.on(events.NewMessage(chats=CHANNELS))
async def handler(event):
    from backend.database import SessionLocal
    from backend.models import Report
    from core.geoparse import claude_geoparse

    text = event.message.text or ""
    if len(text) < 20:
        return

    complaint_keywords = ['яма', 'фонарь', 'мусор', 'потоп', 'дыра']
    if not any(kw in text.lower() for kw in complaint_keywords):
        return

    print(f"🚨 Complaint: {text[:100]}...")

    try:
        lat, lng, address = await claude_geoparse(text)
    except Exception as e:
        print(f"Claude geoparse error: {e}")
        lat, lng, address = 61.034, 76.553, "Нижневартовск центр"

    db = SessionLocal()
    try:
        report = Report(
            title=f"TG: {address}",
            description=text[:500],
            lat=lat,
            lng=lng,
            category="auto"
        )
        db.add(report)
        db.commit()
        print(f"💾 #{report.id} {address} [{lat:.4f},{lng:.4f}]")
    finally:
        db.close()


async def start():
    await client.start()  # type: ignore[misc]
    print("Claude monitoring started!")
    await client.run_until_disconnected()  # type: ignore[misc]


if __name__ == "__main__":
    asyncio.run(start())
