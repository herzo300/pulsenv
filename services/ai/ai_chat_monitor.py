import asyncio
import json
import os
import time
from datetime import datetime
from pathlib import Path

import httpx
from telethon import TelegramClient, events

# Config
API_ID = os.getenv("TG_API_ID")
API_HASH = os.getenv("TG_API_HASH")
SESSION_NAME = "city_pulse_monitor"
MONITORED_CHANNELS = ["n_vartovsk_news", "chp_nv", "typical_nv"]  # Example channel list
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

REPORT_PATH = Path("c:/Soobshio_project/public/daily_report.json")
CHAT_LOGS_PATH = Path("c:/Soobshio_project/data/chat_logs.json")


class ChatMonitor:
    def __init__(self):
        self.client = (
            TelegramClient(SESSION_NAME, API_ID, API_HASH)
            if API_ID and API_HASH
            else None
        )
        self.daily_buffer = []

    async def start(self):
        if not self.client:
            print("⚠️ TG_API_ID or TG_API_HASH not set. Chat monitoring disabled.")
            return

        await self.client.start()
        print(f"📡 Chat Monitor active on {len(MONITORED_CHANNELS)} channels.")

        @self.client.on(events.NewMessage(chats=MONITORED_CHANNELS))
        async def handler(event):
            text = event.message.message
            channel = event.chat.username or str(event.chat_id)
            print(f"📩 New message from {channel}: {text[:50]}...")

            self.daily_buffer.append(
                {"time": time.time(), "channel": channel, "text": text}
            )
            self.save_logs()

    def save_logs(self):
        CHAT_LOGS_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(CHAT_LOGS_PATH, "w", encoding="utf-8") as f:
            json.dump(self.daily_buffer, f, ensure_ascii=False, indent=2)

    async def generate_daily_summary(self):
        """
        Runs at the end of the day. Uses LLM to summarize city situation.
        """
        if not self.daily_buffer:
            return "Сегодня в городских чатах было спокойно."

        # Prepare text for AI (truncate if too big)
        combined_text = "\n---\n".join(
            [f"[{m['channel']}]: {m['text'][:200]}" for m in self.daily_buffer[-50:]]
        )

        prompt = (
            f"Ниже приведены сообщения из городских чатов Нижневартовска за сегодня. \n"
            f"Проанализируй их и составь краткий отчет ситуации в городе (3-5 пунктов). \n"
            f"Выдели основные проблемы (ЖКХ, транспорт, ЧП) и общее настроение жителей. \n\n{combined_text}"
        )

        try:
            async with httpx.AsyncClient() as client:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={GEMINI_API_KEY}"
                payload = {"contents": [{"parts": [{"text": prompt}]}]}
                resp = await client.post(url, json=payload, timeout=30.0)
                if resp.status_code == 200:
                    summary = resp.json()["candidates"][0]["content"]["parts"][0][
                        "text"
                    ]
                    return summary
        except Exception as e:
            print(f"AI Summary Error: {e}")
            return "Ошибка при генерации ИИ-отчета."

    async def run_daily_report_task(self):
        while True:
            now = datetime.now()
            # Run at 23:50
            if now.hour == 23 and now.minute == 50:
                print("🌙 Generating Daily City Report...")
                ai_sum = await self.generate_daily_summary()

                # Load other data (cameras, complaints)
                cam_events_path = Path("c:/Soobshio_project/public/ai_events.json")
                cam_count = 0
                if cam_events_path.exists():
                    with open(cam_events_path, encoding="utf-8") as f:
                        cam_count = len(json.load(f))

                report = {
                    "date": now.strftime("%d.%m.%Y"),
                    "ai_chat_summary": ai_sum,
                    "stats": {
                        "messages_processed": len(self.daily_buffer),
                        "ai_camera_alerts": cam_count,
                        "city_mood": "Stable",  # Could be analyzed by AI too
                    },
                    "timestamp": time.time(),
                }

                with open(REPORT_PATH, "w", encoding="utf-8") as f:
                    json.dump(report, f, ensure_ascii=False, indent=2)

                # Clear buffer for next day
                self.daily_buffer = []
                self.save_logs()

                await asyncio.sleep(120)  # Wait to avoid double run
            await asyncio.sleep(40)


if __name__ == "__main__":
    monitor = ChatMonitor()
    loop = asyncio.get_event_loop()
    loop.create_task(monitor.start())
    loop.run_until_complete(monitor.run_daily_report_task())
