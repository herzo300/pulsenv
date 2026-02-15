#!/usr/bin/env python3
"""Auth monitoring session - waits for code in _tg_code.txt"""
import asyncio, os, time
from dotenv import load_dotenv
load_dotenv()
from telethon import TelegramClient
from telethon.errors import SessionPasswordNeededError

API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')
PASSWORD = 'j498drz5ke'

async def main():
    client = TelegramClient('monitoring_session', API_ID, API_HASH)
    await client.connect()
    if await client.is_user_authorized():
        me = await client.get_me()
        print(f"Already authorized: {me.first_name} (@{me.username})")
        await client.disconnect()
        return
    # Request code
    print("Requesting new code...")
    result = await client.send_code_request(PHONE)
    print(f"Code sent! phone_code_hash={result.phone_code_hash[:10]}...")
    print("WAITING FOR CODE - enter it as next message")
    # Read code from file
    import time
    code_file = "_tg_code.txt"
    if os.path.exists(code_file):
        os.remove(code_file)
    print(f"Write code to {code_file} file...")
    for i in range(120):
        if os.path.exists(code_file):
            with open(code_file) as f:
                code = f.read().strip()
            if code:
                print(f"Got code: {code}")
                try:
                    await client.sign_in(PHONE, code, phone_code_hash=result.phone_code_hash)
                except SessionPasswordNeededError:
                    print("2FA required, entering password...")
                    await client.sign_in(password=PASSWORD)
                me = await client.get_me()
                print(f"Authorized: {me.first_name} (@{me.username})")
                break
        time.sleep(1)
    else:
        print("Timeout waiting for code")
    await client.disconnect()

asyncio.run(main())
