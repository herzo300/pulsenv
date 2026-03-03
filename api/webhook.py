"""
Vercel Serverless Function для Telegram webhook.
"""
import os
import json
import asyncio

from http.server import BaseHTTPRequestHandler


# Minimal bot handler
async def process_update(update: dict):
    """Process Telegram update."""
    import httpx
    
    token = os.environ.get("TG_BOT_TOKEN", "")
    if not token:
        return
    
    message = update.get("message") or update.get("callback_query", {}).get("message")
    if not message:
        return
    
    chat_id = message.get("chat", {}).get("id")
    text = message.get("text", "")
    
    if not chat_id:
        return
    
    # Simple echo for testing
    if text == "/start":
        reply = "👋 Привет! Бот Пульс города Нижневартовска работает через webhook."
    elif text == "/help":
        reply = "Используйте меню бота для доступа к карте и инфографике."
    else:
        return  # Don't reply to other messages
    
    async with httpx.AsyncClient() as client:
        await client.post(
            f"https://api.telegram.org/bot{token}/sendMessage",
            json={"chat_id": chat_id, "text": reply}
        )


class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        
        try:
            update = json.loads(body)
            asyncio.run(process_update(update))
        except Exception as e:
            print(f"Webhook error: {e}")
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"ok": true}')
    
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"status": "ok", "service": "pulsenv-webhook"}')
