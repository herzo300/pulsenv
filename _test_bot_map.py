"""Send /map command to bot to test"""
import asyncio
from aiogram import Bot

BOT_TOKEN = "8535229948:AAF5nvKxCU7nDpbimunheAP9eWRTC8R1R0g"

async def main():
    bot = Bot(token=BOT_TOKEN)
    info = await bot.get_me()
    print(f"Bot: @{info.username}")
    # Get webhook info
    wh = await bot.get_webhook_info()
    print(f"Webhook: {wh.url or 'none (polling)'}")
    await bot.session.close()

asyncio.run(main())
