#!/usr/bin/env python3
"""
Мониторинг Telegram каналов Нижневартовска
AI анализ → фильтрация → геокодинг → публикация в @monitornv
"""

import asyncio
import logging
import sys
import os
import re
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

from telethon import TelegramClient, events
from services.zai_service import analyze_complaint, CATEGORIES
from services.geo_service import get_coordinates, geoparse
from services.realtime_guard import RealtimeGuard

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Конфигурация
API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')
TARGET_CHANNEL = '@monitornv'

# Каналы для мониторинга
CHANNELS_TO_MONITOR = [
    '@nizhnevartovsk_chp',
    '@Nizhnevartovskd',
    '@chp_nv_86',
    '@accidents_in_nizhnevartovsk',
    '@Nizhnevartovsk_podslushal',
    '@justnow_nv',
    '@nv86_me',
    '@adm_nvartovsk',
]

EMOJI = {
    "ЖКХ": "🏘️", "Дороги": "🛣️", "Благоустройство": "🌳", "Транспорт": "🚌",
    "Экология": "♻️", "Животные": "🐶", "Торговля": "🛒", "Безопасность": "🚨",
    "Снег/Наледь": "❄️", "Освещение": "💡", "Медицина": "🏥", "Образование": "🏫",
    "Связь": "📶", "Строительство": "🚧", "Парковки": "🅿️", "Прочее": "❔",
    "ЧП": "🚨", "Газоснабжение": "🔥", "Водоснабжение и канализация": "💧",
    "Отопление": "🌡️", "Бытовой мусор": "🗑️", "Лифты и подъезды": "🏢",
    "Парки и скверы": "🌲", "Спортивные площадки": "⚽", "Детские площадки": "🎠",
    "Социальная сфера": "👥", "Трудовое право": "📄",
}

TAG = {
    "ЖКХ": "ЖКХ", "Дороги": "дороги", "Благоустройство": "благоустройство",
    "Транспорт": "транспорт", "Экология": "экология", "Снег/Наледь": "снег",
    "Освещение": "освещение", "Безопасность": "безопасность", "Прочее": "прочее",
    "ЧП": "ЧП", "Медицина": "медицина", "Бытовой мусор": "мусор",
    "Водоснабжение и канализация": "водоснабжение", "Отопление": "отопление",
    "Газоснабжение": "газ", "Лифты и подъезды": "подъезды",
    "Детские площадки": "детские_площадки", "Парки и скверы": "парки",
    "Строительство": "стройка", "Парковки": "парковки",
}

# ============================================================
# ФИЛЬТРАЦИЯ: правила отбора жалоб
# ============================================================

# Слова-маркеры рекламы и нерелевантного контента
AD_KEYWORDS = [
    "реклама", "промокод", "скидк", "акция", "распродаж", "купи", "закажи",
    "доставк", "магазин", "интернет-магазин", "подписывайтесь", "подпишись",
    "розыгрыш", "конкурс", "приз", "выигра", "бесплатн", "бонус",
    "кредит", "займ", "ипотек", "инвестиц", "заработ", "доход",
    "казино", "ставк", "букмекер", "тотализатор",
    "знакомств", "свидани", "отношени",
    "гороскоп", "предсказан", "гадани",
    "курс валют", "биткоин", "крипт",
    "продаётся", "продается", "сдаётся", "сдается", "аренд", "купить",
    "вакансия", "требуется сотрудник", "ищем работник",
    "гороскоп", "telegram.me", "t.me/joinchat", "taplink", "inst:", "@.*_bot",
]

# Паттерны ссылок на сторонние ресурсы (реклама)
AD_URL_PATTERNS = [
    r'(?:bit\.ly|goo\.gl|clck\.ru|vk\.cc|taplink\.cc)',
    r'(?:t\.me/(?!nizhnevartovsk|Nizhnevartovsk|chp_nv|nv86|justnow|adm_nvartovsk|monitornv|accidents))\S+',
]

# Минимальная длина текста для анализа
MIN_TEXT_LENGTH = 20

# Категории, которые считаются жалобами/проблемами (релевантные)
RELEVANT_CATEGORIES = [
    "ЖКХ", "Дороги", "Благоустройство", "Транспорт", "Экология",
    "Животные", "Безопасность", "Снег/Наледь", "Освещение",
    "Медицина", "Строительство", "Парковки", "ЧП",
    "Газоснабжение", "Водоснабжение и канализация", "Отопление",
    "Бытовой мусор", "Лифты и подъезды", "Парки и скверы",
    "Спортивные площадки", "Детские площадки",
]

# Слова-маркеры жалоб/проблем (повышают релевантность)
COMPLAINT_MARKERS = [
    "проблем", "жалоб", "не работает", "сломан", "разбит", "поломк",
    "авари", "прорыв", "прорвал", "затоп", "течь", "течёт", "протечк",
    "яма", "выбоин", "колея", "трещин",
    "не убира", "не чист", "грязн", "мусор", "свалк",
    "не горит", "не свет", "темно", "фонар",
    "опасн", "угроз", "вандал", "хулиган",
    "пожар", "взрыв", "обрушен", "провал",
    "запах", "вонь", "дым", "загрязн",
    "шум", "громк",
    "холодн", "не греет", "отключ",
    "просим", "требуем", "когда", "сколько можно", "надоело",
    "помогите", "обратите внимание", "срочно",
    "ДТП", "дтп", "столкнов", "наезд",
]


def is_ad_or_spam(text: str) -> bool:
    """Проверяет, является ли текст рекламой или спамом"""
    t = text.lower()
    # Проверка ключевых слов рекламы
    ad_count = sum(1 for kw in AD_KEYWORDS if kw in t)
    if ad_count >= 1 and any(kw in t for kw in [
        "промокод", "розыгрыш", "казино", "букмекер", "гороскоп",
        "продаётся", "продается", "сдаётся", "сдается",
        "вакансия", "taplink",
    ]):
        return True
    if ad_count >= 2:
        return True
    # Проверка рекламных URL
    for pat in AD_URL_PATTERNS:
        if re.search(pat, text, re.IGNORECASE):
            return True
    # Слишком много эмодзи (типичный признак рекламы)
    emoji_count = len(re.findall(r'[\U0001F300-\U0001F9FF]', text))
    if emoji_count > 10 and len(text) < 200:
        return True
    # Слишком много хэштегов
    hashtag_count = text.count('#')
    if hashtag_count > 5:
        return True
    return False


def has_complaint_markers(text: str) -> bool:
    """Проверяет наличие маркеров жалобы/проблемы"""
    t = text.lower()
    return any(m in t for m in COMPLAINT_MARKERS)


def is_relevant_message(text: str, category: str) -> bool:
    """
    Определяет, релевантно ли сообщение для публикации.
    Пропускает: рекламу, новости без проблем, развлечения, объявления.
    Публикует: жалобы, проблемы, ЧП, аварии.
    """
    # Слишком короткий текст
    if len(text.strip()) < MIN_TEXT_LENGTH:
        return False

    # Реклама/спам — отсеиваем
    if is_ad_or_spam(text):
        return False

    # Категория из списка релевантных — публикуем
    if category in RELEVANT_CATEGORIES:
        return True

    # Есть маркеры жалобы — публикуем даже если категория "Прочее"
    if has_complaint_markers(text):
        return True

    # Нерелевантные категории без маркеров — пропускаем
    return False


def build_message_link(channel_username: str, message_id: int) -> str:
    """Формирует ссылку на оригинальное сообщение"""
    username = channel_username.lstrip('@')
    return f"https://t.me/{username}/{message_id}"


# Статистика
stats = {
    'total': 0,
    'filtered_ad': 0,
    'filtered_irrelevant': 0,
    'published': 0,
    'by_category': {},
}


async def analyze_and_publish(client, event):
    """Анализирует сообщение, фильтрует, публикует релевантные жалобы"""
    try:
        text = event.message.text or event.message.message or ""
        if not text or len(text.strip()) < MIN_TEXT_LENGTH:
            return

        channel_username = event.chat.username or ""
        channel_title = event.chat.title or channel_username
        message_id = event.message.id
        msg_link = build_message_link(channel_username, message_id)

        stats['total'] += 1

        # 1. Быстрая проверка на рекламу (до AI)
        if is_ad_or_spam(text):
            stats['filtered_ad'] += 1
            logger.info(f"🚫 Реклама/спам из @{channel_username}: {text[:40]}...")
            return

        # 2. AI анализ
        logger.info(f"🤖 Анализ из @{channel_username}: {text[:50]}...")
        analysis = await analyze_complaint(text)
        category = analysis.get('category', 'Прочее')
        address = analysis.get('address')
        summary = analysis.get('summary', text[:100])
        provider = analysis.get('provider', '?')
        location_hints = analysis.get('location_hints')

        # 3. AI фильтрация: если AI сказал не релевантно — пропускаем
        if not analysis.get('relevant', True):
            stats['filtered_irrelevant'] += 1
            logger.info(f"⏭️ AI: нерелевантно [{provider}] из @{channel_username}: {text[:40]}...")
            return

        # 4. Keyword-based проверка релевантности
        if not is_relevant_message(text, category):
            stats['filtered_irrelevant'] += 1
            logger.info(f"⏭️  Нерелевантно ({category}) из @{channel_username}: {text[:40]}...")
            return

        # 5. Геопарсинг (улучшенный: AI адрес → парсер → ориентиры → hints)
        geo = await geoparse(text, ai_address=address, location_hints=location_hints)
        lat = geo.get("lat")
        lon = geo.get("lng")
        if geo.get("address"):
            address = geo["address"]

        # 5. Сохранение в БД
        try:
            from backend.database import SessionLocal
            from backend.models import Report
            db = SessionLocal()
            report = Report(
                title=summary[:200],
                description=text[:2000],
                lat=lat,
                lng=lon,
                address=address,
                category=category,
                status="open",
                source=f"monitor:@{channel_username}",
                telegram_message_id=message_id,
                telegram_channel=f"@{channel_username}",
            )
            db.add(report)
            db.commit()
            report_id = report.id
            db.close()
        except Exception as e:
            logger.error(f"DB error: {e}")
            report_id = None

        # 6. Формируем пост для @monitornv
        emoji = EMOJI.get(category, "❔")
        tag = TAG.get(category, category.replace(" ", "_"))

        lines = [f"{emoji} {category}"]
        if report_id:
            lines[0] += f" #{report_id}"
        lines.append("")
        lines.append(f"📝 {summary}")
        if address:
            lines.append(f"📍 {address}")
        if lat and lon:
            lines.append(f"🗺️ {lat:.4f}, {lon:.4f}")
            sv_url = f"https://www.google.com/maps/@?api=1&map_action=pano&viewpoint={lat},{lon}&heading=0&pitch=0&fov=90"
            map_url = f"https://www.google.com/maps/search/?api=1&query={lat},{lon}"
            lines.append(f'👁 <a href="{sv_url}">Street View</a> | 📌 <a href="{map_url}">Карта</a>')
        lines.append("")
        lines.append(f"📢 @{channel_username}")
        lines.append(f"🔗 {msg_link}")
        lines.append(f"🕐 {datetime.now().strftime('%d.%m.%Y %H:%M')}")
        lines.append("")
        lines.append(f"#{tag} #ПульсГорода #Нижневартовск")

        post_text = "\n".join(lines)

        # 7. Публикация
        if TARGET_CHANNEL:
            try:
                await client.send_message(TARGET_CHANNEL, post_text, parse_mode='html')
                stats['published'] += 1
                logger.info(f"✅ [{provider}] {category} из @{channel_username} → @monitornv")
            except Exception as e:
                logger.error(f"❌ Публикация: {e}")

        # Статистика по категориям
        stats['by_category'][category] = stats['by_category'].get(category, 0) + 1

    except Exception as e:
        logger.error(f"❌ Ошибка обработки: {e}", exc_info=True)


async def main():
    """Главная функция мониторинга"""
    logger.info("🚀 Запуск мониторинга Telegram каналов...")

    if not API_ID or not API_HASH:
        logger.error("❌ TG_API_ID или TG_API_HASH не найдены в .env")
        return

    # Инициализация RealtimeGuard
    guard = RealtimeGuard()
    logger.info(f"⏱️ Время запуска (UTC): {guard.startup_time.isoformat()}")

    client = TelegramClient('monitoring_session', API_ID, API_HASH)

    try:
        await client.start(phone=PHONE)
        logger.info("✅ Подключено к Telegram")

        me = await client.get_me()
        logger.info(f"👤 {me.first_name} (@{me.username})")

        if TARGET_CHANNEL:
            try:
                ch = await client.get_entity(TARGET_CHANNEL)
                logger.info(f"✅ Целевой канал: {ch.title}")
            except Exception as e:
                logger.error(f"❌ Канал {TARGET_CHANNEL}: {e}")

        logger.info(f"📡 Мониторинг {len(CHANNELS_TO_MONITOR)} каналов:")
        for c in CHANNELS_TO_MONITOR:
            logger.info(f"   • {c}")

        logger.info("📋 Фильтры: реклама, спам, нерелевантные посты — отсеиваются")
        logger.info(f"📋 Релевантные категории: {len(RELEVANT_CATEGORIES)}")
        logger.info("🛡️ RealtimeGuard: только новые сообщения + дедупликация")

        @client.on(events.NewMessage(chats=CHANNELS_TO_MONITOR))
        async def handler(event):
            # RealtimeGuard: проверка таймстемпа
            msg_time = event.message.date
            if not guard.is_new_message(msg_time):
                channel = event.chat.username or ""
                logger.info(f"⏭️ Старое сообщение: @{channel}/{event.message.id}, время: {msg_time}")
                return

            # RealtimeGuard: проверка дубликата
            source = f"tg:{event.chat.username or ''}"
            if guard.is_duplicate(source, event.message.id):
                logger.debug(f"⏭️ Дубликат: {source}/{event.message.id}")
                return

            await analyze_and_publish(client, event)

            # Отмечаем как обработанное
            guard.mark_processed(source, event.message.id)

            # Статистика каждые 10 сообщений
            if stats['total'] % 10 == 0 and stats['total'] > 0:
                gs = guard.stats
                logger.info(
                    f"📊 Всего: {stats['total']} | "
                    f"Опубликовано: {stats['published']} | "
                    f"Реклама: {stats['filtered_ad']} | "
                    f"Нерелевантно: {stats['filtered_irrelevant']} | "
                    f"🛡️ Старые: {gs.skipped_old} | Дубли: {gs.skipped_duplicate}"
                )

        logger.info("🤖 Мониторинг запущен! Ожидание сообщений...")
        logger.info("⏹️ Ctrl+C для остановки")

        await client.run_until_disconnected()

    except KeyboardInterrupt:
        logger.info("⏹️ Остановка...")
    except Exception as e:
        logger.error(f"❌ {e}", exc_info=True)
    finally:
        logger.info(f"📊 Итого: {stats['total']} сообщений, "
                     f"{stats['published']} опубликовано, "
                     f"{stats['filtered_ad']} реклама, "
                     f"{stats['filtered_irrelevant']} нерелевантно")
        for cat, cnt in sorted(stats['by_category'].items(), key=lambda x: x[1], reverse=True):
            logger.info(f"   {EMOJI.get(cat, '❔')} {cat}: {cnt}")
        await client.disconnect()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("⏹️ Мониторинг остановлен")
