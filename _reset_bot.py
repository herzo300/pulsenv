"""Reset bot: delete webhook, drop pending updates"""
import asyncio
from aiogram import Bot

async def main():
    bot = Bot(token="8535229948:AAF5nvKxCU7nDpbimunheAP9eWRTC8R1R0g")
    await bot.delete_webhook(drop_pending_updates=True)
    print("Webhook deleted, pending updates dropped")
    await bot.session.close()

asyncio.run(main())
