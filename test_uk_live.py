"""Live test: отправляем жалобу с адресом и проверяем что УК определена."""
import asyncio, os, sys, time
from dotenv import load_dotenv
load_dotenv()

from telethon import TelegramClient

API_ID = int(os.getenv("TG_API_ID", "0"))
API_HASH = os.getenv("TG_API_HASH", "").strip('"')
BOT = "@pulsenvbot"

async def main():
    client = TelegramClient("test_bot_session", API_ID, API_HASH)
    await client.start(phone="+18457266658", password="j498drz5ke")
    print("Connected")

    # Уникальный текст чтобы не поймать старый ответ
    ts = int(time.time())
    complaint = f"Разбитый тротуар возле дома по улице Мира 25, Нижневартовск. Плитка разбита #{ts}"
    await client.send_message(BOT, complaint)
    print(f"Sent: {complaint}")

    await asyncio.sleep(20)
    msgs = await client.get_messages(BOT, limit=5)
    
    found_uk = False
    found_email_btn = False
    confirmed = False
    
    for msg in msgs:
        if not msg.text:
            continue
        if str(ts) not in msg.text and "Результат AI" not in msg.text:
            continue
        if "Результат AI" in msg.text:
            print(f"\nAI response:\n{msg.text[:500]}")
            
            # Нажимаем подтвердить
            if msg.reply_markup:
                for row in msg.reply_markup.rows:
                    for btn in row.buttons:
                        data = (getattr(btn, 'data', b'') or b'')
                        if isinstance(data, bytes):
                            data = data.decode('utf-8', errors='ignore')
                        if data == "confirm":
                            await msg.click(data=b"confirm")
                            confirmed = True
                            print("Clicked confirm")
                            break
                    if confirmed:
                        break
    
    if confirmed:
        await asyncio.sleep(10)
        msgs2 = await client.get_messages(BOT, limit=3)
        for m in msgs2:
            if m.text and "сохранена" in m.text.lower():
                print(f"\nAfter confirm:\n{m.text[:600]}")
                if any(x in m.text for x in ["ПРЭТ", "обслуживает", "Отправить в УК"]):
                    found_uk = True
                if m.reply_markup:
                    for row in m.reply_markup.rows:
                        for btn in row.buttons:
                            data = (getattr(btn, 'data', b'') or b'')
                            if isinstance(data, bytes):
                                data = data.decode('utf-8', errors='ignore')
                            print(f"  Btn: [{btn.text}] data={data}")
                            if "send_to_uk" in data:
                                found_email_btn = True

    print(f"\n{'='*40}")
    print(f"UK found: {'YES' if found_uk else 'NO'}")
    print(f"Email btn: {'YES' if found_email_btn else 'NO'}")
    
    await client.disconnect()

asyncio.run(main())
