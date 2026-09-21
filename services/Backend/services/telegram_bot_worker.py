import asyncio
import logging
import os

import httpx

logger = logging.getLogger(__name__)


def _token() -> str:
    return os.getenv("TG_BOT_TOKEN", "").strip(chr(34))


PROXY = os.getenv("TELEGRAM_PROXY", "socks5://tor:9050")
API = "https://api.telegram.org/bot{token}/{method}"
_last_offset = 0
NL = chr(10)

HELP_TEXT = NL.join([
    "Пульс города - бот жителя Нижневартовска.",
    "",
    "/apk - свежая сборка приложения (ARM64)",
    "/weather - погода сейчас",
    "/help - эта справка",
    "",
    "Отправьте адрес дома текстом - подключу ИИ-мониторинг 24/7.",
])


def _client() -> httpx.AsyncClient:
    return httpx.AsyncClient(proxy=PROXY or None, timeout=60.0)


async def _api(method: str, **payload) -> dict:
    async with _client() as c:
        r = await c.post(API.format(token=_token(), method=method), json=payload)
        return r.json()


async def _handle_update(u: dict) -> None:
    global _last_offset
    _last_offset = max(_last_offset, u.get("update_id", 0) + 1)
    msg = u.get("message") or u.get("edited_message") or {}
    if not msg:
        return
    chat_id = msg.get("chat", {}).get("id")
    text = (msg.get("text") or "").strip()
    if chat_id is None:
        return
    try:
        if text.startswith("/start"):
            hello = "Привет! Я бот Пульс города - помощник жителя Нижневартовска." + NL + NL + HELP_TEXT
            await _api("sendMessage", chat_id=chat_id, text=hello)
        elif text.startswith("/apk"):
            apk_msg = "Ссылка: https://45.153.68.59/app-arm64-v8a-release.apk" + NL + "MD5: 886d289a17b4498d2692fa17334238e4"
            await _api("sendMessage", chat_id=chat_id, text=apk_msg)
        elif text.startswith("/help"):
            await _api("sendMessage", chat_id=chat_id, text=HELP_TEXT)
        elif text.startswith("/weather"):
            await _api("sendMessage", chat_id=chat_id, text="Смотрите погоду в приложении: живое небо, Шуман, аврора")
        else:
            connected = False
            try:
                r = httpx.post(
                    "http://localhost:8000/api/hermes/house-agent/task",
                    json={"address": text, "user_id": str(chat_id)},
                    timeout=8.0,
                )
                if r.status_code == 200 and r.json().get("success"):
                    connected = True
            except Exception:
                pass
            if connected:
                ok_msg = "Подключил ИИ-Гермес мониторинг 24/7 для: " + text + NL + "Отключения и новости по дому будут приходить сюда."
                await _api("sendMessage", chat_id=chat_id, text=ok_msg)
            else:
                await _api("sendMessage", chat_id=chat_id, text="Опишите вопрос подробнее или отправьте адрес дома - подключу круглосуточный мониторинг. /help - справка.")
    except Exception as e:
        logger.warning("bot handle error: %s", e)


async def run_bot_forever() -> None:
    logger.info("Telegram bot worker (long-polling) started")
    while True:
        try:
            async with _client() as c:
                r = await c.get(
                    API.format(token=_token(), method="getUpdates")
                    + "?timeout=25&offset=" + str(_last_offset)
                )
                for u in r.json().get("result", []):
                    await _handle_update(u)
        except Exception as e:
            logger.debug("bot poll error: %s", e)
            await asyncio.sleep(5)
