import os
import asyncio
import json
import sys
import platform

# Добавляем корневую папку проекта в путь
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
from telethon import TelegramClient, events
from telethon.errors import SessionPasswordNeededError
import logging
import httpx
from services.geo_service import get_coordinates, make_street_view_url

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Загружаем переменные из .env
load_dotenv()

# AI Client с fallback
ai_client = None
ai_model = None
ai_provider = None

try:
    # Пробуем Zai (GLM-4.7)
    ai_client = "zai"
    ai_model = "glm-4.7-flash"
    ai_provider = "zai"
    logger.info("✅ Используется Zai (GLM-4.7-flash)")
except Exception as e:
    logger.error(f"❌ Zai недоступен: {e}")

# Твои данные из my.telegram.org
api_id = int(os.getenv('TG_API_ID', '1234567'))
api_hash = os.getenv('TG_API_HASH', 'your_hash')

# Проверяем, что переменные загружены
if api_id == 1234567 or api_hash == 'your_hash':
    logger.error("ERROR: You must set TG_API_ID and TG_API_HASH in .env file!")
    sys.exit(1)

# Загружаем целевой канал из .env
global target_channel
target_channel = os.getenv('TARGET_CHANNEL')
if not target_channel:
    logger.warning("TARGET_CHANNEL not set in .env - auto-publishing disabled")

# Список из 15 каналов Нижневартовска
channels = [
    'nizhnevartovsk_chp',
    'adm_nvartovsk',
    'justnow_nv',
    'nv86_me',
    'nv_chp',
    'Nizhnevartovskd',
    'chp_nv_86',
    'n1_tv',
    'chp_nv_86',
    'accidents_in_nizhnevartovsk',
    'Nizhnevartovsk_narod',
    'Nizhnevartovsk_podslushal',
]

# Категории жалоб
CATEGORIES = [
    "ЖКХ",
    "Дороги",
    "Благоустройство",
    "Транспорт",
    "Экология",
    "Животные",
    "Торговля",
    "Безопасность",
    "Снег/Наледь",
    "Освещение",
    "Медицина",
    "Образование",
    "Связь",
    "Строительство",
    "Парковки",
    "Социальная сфера",
    "Трудовое право",
    "Прочее",
    "ЧП"
]

# Глобальная переменная для клиента (будет инициализирована в main)
client = None

# Целевой канал для публикации (из .env)
target_channel = None
# Иконки по категориям

CATEGORY_EMOJI = {
    "ЖКХ": "🏘️",
    "Дороги": "🛣️",
    "Благоустройство": "🌳",
    "Транспорт": "🚌",
    "Экология": "♻️",
    "Животные": "🐶",
    "Торговля": "🛒",
    "Безопасность": "🚨",
    "Снег/Наледь": "❄️",
    "Освещение": "💡",
    "Медицина": "🏥",
    "Образование": "🏫",
    "Связь": "📶",
    "Строительство": "🚧",
    "Парковки": "🅿️",
    "Социальная сфера": "👥",
    "Трудовое право": "📄",
    "Прочее": "❔",
}

# Хэштеги по категориям (без #, добавим при формировании текста)

CATEGORY_TAG = {
    "ЖКХ": "жкх",
    "Дороги": "дороги",
    "Благоустройство": "благоустройство",
    "Транспорт": "транспорт",
    "Экология": "экология",
    "Животные": "животные",
    "Торговля": "торговля",
    "Безопасность": "безопасность",
    "Снег/Наледь": "снег",
    "Освещение": "освещение",
    "Медицина": "медицина",
    "Образование": "образование",
    "Связь": "связь",
    "Строительство": "стройка",
    "Парковки": "парковка",
    "Социальная сфера": "соцсфера",
    "Трудовое право": "труд",
    "Прочее": "прочее",
    "ЧП": "ЧП",
}


async def analyze_complaint(text: str) -> dict:
    """
    Анализирует текст жалобы через Zai GLM-4.7.
    Возвращает JSON с категорией, адресом и резюме.
    """
    try:
        from services.zai_service import analyze_complaint as zai_analyze
        result = await zai_analyze(text)
        logger.info(f"Zai analysis: {result}")
        return result
    except Exception as e:
        logger.error(f"Zai error: {e}")
        return {"category": "Прочее", "address": None, "summary": text[:100]}
    
    try:
        prompt = f"""Ты — аналитик городских проблем Нижневартовска.
Проанализируй текст и выдели:
1. Категорию из списка: {', '.join(CATEGORIES)}
2. Точный адрес (улица, номер дома), если есть. Если адреса нет, верни null
3. Краткое резюме (до 100 символов)

Текст: {text}

Верни ответ ТОЛЬКО в формате JSON без дополнительного текста:
{{"category": "название_категории", "address": "адрес или null", "summary": "краткое описание"}}"""

        if ai_provider == "anthropic":
            # Используем Anthropic (Claude)
            message = ai_client.messages.create(
                model=ai_model,
                max_tokens=300,
                messages=[{"role": "user", "content": prompt}]
            )
            response_text = message.content[0].text.strip()
        else:
            # Используем OpenAI
            response = ai_client.chat.completions.create(
                model=ai_model,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=300,
                temperature=0.3
            )
            response_text = response.choices[0].message.content.strip()
        


        # Парсим JSON
        analysis = json.loads(response_text)
        logger.info(f"AI ({ai_provider}) analysis: {analysis}")
        return analysis

    except json.JSONDecodeError as e:
        logger.error(f"JSON parsing error: {e}")
        return {"category": "Прочее", "address": None, "summary": text[:100]}
    except Exception as e:
        logger.error(f"Error analyzing complaint: {e}")
        return {"category": "Прочее", "address": None, "summary": text[:100]}


async def my_event_handler(event):
    """
    Обработчик новых сообщений из отслеживаемых каналов.
    """
    try:
        if not event.message.text or len(event.message.text) < 10:
            return

        text = event.message.text
        logger.info(f"New message from {event.chat.title}: {text[:50]}...")

        # 1. Анализ через Claude
        analysis = await analyze_complaint(text)
        category = analysis.get("category") or "Прочее"
        address = analysis.get("address")
        summary = analysis.get("summary") or text[:100]

        # Защита, если Claude вернул незнакомую категорию
        if category not in CATEGORIES:
            category = "Прочее"

        emoji = CATEGORY_EMOJI.get(category, "❔")
        tag = CATEGORY_TAG.get(category, "прочее")

        lat, lon = None, None
        street_view_url = None

        # 2. Геопарсинг (адрес → координаты → Street View)
        if address:
            coords = await get_coordinates(address)
            if coords:
                lat, lon = coords
                street_view_url = make_street_view_url(lat, lon)  # Street View вместо обычной карты

        # 3. Отправка в FastAPI (если уже настроено)
        try:
            resp = httpx.post(
                "http://127.0.0.1:8000/complaints",
                json={
                    "source": event.chat.title or "unknown",
                    "raw_text": text,
                    "category": category,
                    "address": address,
                    "latitude": lat,
                    "longitude": lon,
                    "summary": summary,
                },
                timeout=5.0,
            )
            logger.info(f"API response: {resp.status_code}")
        except Exception as e:
            logger.error(f"Error sending to API: {e}")

        # 4. Формируем текст автопубликации
        lines = []

        # Заголовок с иконкой
        lines.append(f"{emoji} [{category}] {summary}")

        if address:
            lines.append(f"📍 Адрес: {address}")

        # Ссылка Street View, если нашли координаты
        if street_view_url:
            lines.append(f"👁 Street View: {street_view_url}")

        # Хэштеги внизу
        lines.append(f"\n#{tag} #СообщиО #Нижневартовск")

        publish_text = "\n".join(lines)

        # 5. Публикация в твой служебный канал
        if target_channel and client:
            try:
                await client.send_message(entity=int(target_channel) if target_channel.lstrip('-').isdigit() else target_channel, message=publish_text)
                logger.info(f"Published to {target_channel}")
            except Exception as e:
                logger.error(f"Error publishing to channel: {e}")

    except Exception as e:
        logger.error(f"Error in event handler: {e}", exc_info=True)


async def start_parsing():
    """
    Запускает парсер Telegram-каналов:
    - создаёт клиента
    - вешает обработчик my_event_handler
    - держит соединение до остановки
    """
    global client

    # Инициализируем клиента ВНУТРИ корутины, чтобы не было проблем с event loop
    client = TelegramClient('soobshio_session', api_id, api_hash)

    # Регистрируем обработчик новых сообщений
    client.add_event_handler(
        my_event_handler,
        events.NewMessage(chats=channels),
    )  # эквивалент client.on(...)[web:119][web:121]

    logger.info("Connecting to Telegram...")
    await client.start()
    logger.info("Successfully connected to Telegram!")
    logger.info(f"Starting monitoring of {len(channels)} channels...")
    logger.info(f"Channels: {', '.join(channels)}")

    # Ждём, пока клиент не будет отключён (Ctrl+C или ошибка)
    await client.run_until_disconnected()


def main():
    """
    Простая точка входа: используем asyncio.run без ручной политики.
    """
    logger.info(f"OS: {platform.system()}")
    logger.info(f"Python version: {sys.version}")

    try:
        asyncio.run(start_parsing())
    except KeyboardInterrupt:
        logger.info("\nParser stopped by user")
    except Exception as e:
        logger.error(f"Critical error: {e}", exc_info=True)


if __name__ == '__main__':
    main()
