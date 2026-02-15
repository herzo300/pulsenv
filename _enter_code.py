"""Enter Telegram auth code for monitoring session"""
import asyncio, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()
from telethon import TelegramClient

API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')
PASSWORD = os.getenv('TG_2FA_PASSWORD', 'j498drz5ke')

async def main():
    client = TelegramClient('monitoring_session', API_ID, API_HASH)
    await client.start(phone=PHONE, code_callback=lambda: '32125', password=PASSWORD)
    me = await client.get_me()
    print(f"Authorized: {me.first_name} (@{me.username})")
    await client.disconnect()

asyncio.run(main())
