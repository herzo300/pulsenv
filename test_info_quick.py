"""Quick test: send /opendata to bot and check response"""
import asyncio
from telethon import TelegramClient

api_id = 25270628
api_hash = '8eb8c1e5c70e3c200f9b0e1b0e3f4d5a'
BOT = '@pulsenvbot'

async def main():
    client = TelegramClient('test_bot_session', api_id, api_hash)
    await client.start(phone='+18457266658', password='j498drz5ke')
    
    # Send /opendata
    await client.send_message(BOT, '/opendata')
    await asyncio.sleep(3)
    
    msgs = await client.get_messages(BOT, limit=3)
    for m in msgs:
        text = m.text or ''
        print(f"MSG: {text[:200]}")
        if m.reply_markup:
            for row in m.reply_markup.rows:
                for btn in row.buttons:
                    name = getattr(btn, 'text', str(btn))
                    url = getattr(btn, 'url', None)
                    print(f"  BTN: {name} -> {url}")
    
    await client.disconnect()

asyncio.run(main())
