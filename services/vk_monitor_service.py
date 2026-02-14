# services/vk_monitor_service.py
"""
Мониторинг VK пабликов Нижневартовска
Polling wall.get → AI анализ → фильтрация → Firebase + Telegram
"""

import asyncio
import logging
import os
import re
import time
from datetime import datetime
from typing import Any, Dict, List, Optional

import httpx
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# VK API
VK_SERVICE_TOKEN = os.getenv("VK_SERVICE_TOKEN", "")
VK_API_VERSION = "5.199"
VK_API_BASE = "https://api.vk.com/method"

# Паблики Нижневартовска для мониторинга жалоб
# Формат: (screen_name/domain, owner_id, описание)
# ID получены через VK API wall.get
VK_GROUPS = [
    ("typical.nizhnevartovsk", -35704350, "Типичный Нижневартовск"),
    ("4p86r", -95166832, "ЧП Нижневартовск"),
    ("vartovsk86region", -79705900, "ЧП [В] Нижневартовске"),
    ("pvn3466", -166510484, "Подслушано в Нижневартовске"),
    ("club208955764", -208955764, "Подслушано Нижневартовск"),
    ("degur_nv", -59409295, "Дежурный по Городу Нижневартовск"),
    ("tochka_nv", -179085072, "Точка. Нижневартовск"),
    ("mvremya_nv", -48338673, "Местное время Нижневартовск"),
]


# Хранилище последних обработанных постов (post_id → timestamp)
_last_post_ids: Dict[int, int] = {}  # group_id → last_post_id
_processed_posts: set = set()  # множество обработанных post_id

# Правила фильтрации VK постов
VK_AD_KEYWORDS = [
    "реклама", "промокод", "скидк", "акция", "распродаж", "купи", "закажи",
    "доставк", "интернет-магазин", "розыгрыш", "конкурс", "приз",
    "кредит", "займ", "ипотек", "инвестиц", "казино", "ставк", "букмекер",
    "продаётся", "продается", "сдаётся", "сдается", "аренд",
    "вакансия", "требуется сотрудник", "гороскоп", "знакомств",
    "подписывайтесь", "подпишись", "переходи по ссылке",
    "taplink", "inst:", "whatsapp",
]

VK_COMPLAINT_MARKERS = [
    "проблем", "жалоб", "не работает", "сломан", "разбит", "поломк",
    "авари", "прорыв", "затоп", "течь", "течёт", "протечк",
    "яма", "выбоин", "колея", "трещин",
    "не убира", "не чист", "грязн", "мусор", "свалк",
    "не горит", "не свет", "темно", "фонар",
    "опасн", "угроз", "вандал", "хулиган",
    "пожар", "взрыв", "обрушен", "провал",
    "запах", "вонь", "дым", "загрязн",
    "холодн", "не греет", "отключ",
    "просим", "требуем", "когда", "сколько можно", "надоело",
    "помогите", "обратите внимание", "срочно",
    "ДТП", "дтп", "столкнов", "наезд",
    "лифт не работ", "подъезд", "домофон",
    "детск площадк", "качел", "горк",
    "автобус не", "маршрут отмен",
]

MIN_TEXT_LENGTH = 30  # Минимальная длина поста для анализа


def is_vk_ad(text: str) -> bool:
    """Проверяет, является ли VK пост рекламой"""
    t = text.lower()
    ad_count = sum(1 for kw in VK_AD_KEYWORDS if kw in t)
    if ad_count >= 2:
        return True
    # Явные маркеры рекламы
    if any(kw in t for kw in ["промокод", "казино", "букмекер", "гороскоп", "taplink",
                               "продаётся", "продается", "сдаётся", "сдается"]):
        return True
    # Много ссылок — скорее всего реклама
    url_count = len(re.findall(r'https?://\S+', text))
    if url_count >= 3:
        return True
    return False


def has_vk_complaint_markers(text: str) -> bool:
    """Проверяет наличие маркеров жалобы в VK посте"""
    t = text.lower()
    return any(m in t for m in VK_COMPLAINT_MARKERS)


def is_vk_relevant(text: str, category: str) -> bool:
    """Определяет релевантность VK поста"""
    if len(text.strip()) < MIN_TEXT_LENGTH:
        return False
    if is_vk_ad(text):
        return False
    relevant_cats = [
        "ЖКХ", "Дороги", "Благоустройство", "Транспорт", "Экология",
        "Безопасность", "Снег/Наледь", "Освещение", "Медицина",
        "Строительство", "Парковки", "ЧП", "Газоснабжение",
        "Водоснабжение и канализация", "Отопление", "Бытовой мусор",
        "Лифты и подъезды", "Детские площадки", "Парки и скверы",
        "Спортивные площадки", "Животные",
    ]
    if category in relevant_cats:
        return True
    if has_vk_complaint_markers(text):
        return True
    return False


async def vk_api_call(method: str, params: dict) -> Optional[dict]:
    """Вызов VK API"""
    if not VK_SERVICE_TOKEN:
        logger.error("VK_SERVICE_TOKEN не задан в .env")
        return None
    params["access_token"] = VK_SERVICE_TOKEN
    params["v"] = VK_API_VERSION
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            r = await client.get(f"{VK_API_BASE}/{method}", params=params)
            data = r.json()
            if "error" in data:
                logger.error(f"VK API error: {data['error']}")
                return None
            return data.get("response")
    except Exception as e:
        logger.error(f"VK API call error: {e}")
        return None




async def fetch_group_wall(group_id: int, count: int = 10) -> List[dict]:
    """Получает последние посты со стены группы"""
    result = await vk_api_call("wall.get", {
        "owner_id": group_id,
        "count": count,
        "filter": "owner",  # только посты от имени группы
    })
    if not result:
        return []
    return result.get("items", [])


async def fetch_new_posts(group_id: int) -> List[dict]:
    """Получает только новые посты (которые ещё не обработаны)"""
    posts = await fetch_group_wall(group_id, count=20)
    new_posts = []
    for post in posts:
        post_id = post.get("id", 0)
        unique_key = f"{group_id}_{post_id}"
        if unique_key not in _processed_posts:
            _processed_posts.add(unique_key)
            new_posts.append(post)
    # Ограничиваем размер множества (чтобы не росло бесконечно)
    if len(_processed_posts) > 10000:
        # Оставляем последние 5000
        recent = list(_processed_posts)[-5000:]
        _processed_posts.clear()
        _processed_posts.update(recent)
    return new_posts


def extract_post_text(post: dict) -> str:
    """Извлекает текст из VK поста (включая репосты)"""
    text = post.get("text", "")
    # Если есть репост — добавляем текст оригинала
    copy_history = post.get("copy_history", [])
    if copy_history:
        original_text = copy_history[0].get("text", "")
        if original_text and original_text not in text:
            text = f"{text}\n{original_text}" if text else original_text
    return text.strip()


def build_vk_post_link(group_id: int, post_id: int) -> str:
    """Формирует ссылку на VK пост"""
    owner_id = group_id  # отрицательный для групп
    return f"https://vk.com/wall{owner_id}_{post_id}"


def get_group_name(group_id: int) -> str:
    """Возвращает название группы по ID"""
    for short_name, gid, name in VK_GROUPS:
        if gid == group_id:
            return name
    return f"VK group {group_id}"


def get_group_short_name(group_id: int) -> str:
    """Возвращает short_name группы"""
    for short_name, gid, name in VK_GROUPS:
        if gid == group_id:
            return short_name
    return "vk"


# Статистика VK мониторинга
vk_stats = {
    "total": 0,
    "filtered_ad": 0,
    "filtered_short": 0,
    "filtered_irrelevant": 0,
    "published": 0,
    "errors": 0,
    "by_group": {},
}


async def poll_all_groups(
    on_complaint: Optional[callable] = None,
    poll_interval: int = 120,
    startup_time: Optional[datetime] = None,
):
    """
    Основной цикл polling VK групп.
    on_complaint(post_data) — callback при обнаружении жалобы.
    poll_interval — интервал опроса в секундах (default 2 мин).
    """
    from services.zai_service import analyze_complaint

    if not VK_GROUPS:
        logger.error("❌ Нет VK групп для мониторинга")
        return

    logger.info(f"🔵 VK мониторинг: {len(VK_GROUPS)} групп, интервал {poll_interval}с")
    for short_name, gid, name in VK_GROUPS:
        logger.info(f"   • {name} (id: {gid})")

    # Первый проход — запоминаем текущие посты, не обрабатываем
    logger.info("📋 Инициализация: запоминаем текущие посты...")
    for short_name, group_id, name in VK_GROUPS:
        try:
            posts = await fetch_group_wall(group_id, count=5)
            for post in posts:
                unique_key = f"{group_id}_{post.get('id', 0)}"
                _processed_posts.add(unique_key)
            await asyncio.sleep(0.5)  # Rate limit
        except Exception as e:
            logger.error(f"Init error {name}: {e}")

    logger.info(f"✅ Инициализация завершена, запомнено {len(_processed_posts)} постов")
    logger.info("🔄 Начинаю мониторинг новых постов...")

    while True:
        try:
            for short_name, group_id, name in VK_GROUPS:
                try:
                    new_posts = await fetch_new_posts(group_id)
                    for post in new_posts:
                        text = extract_post_text(post)
                        post_id = post.get("id", 0)
                        post_date = datetime.fromtimestamp(post.get("date", 0))
                        vk_stats["total"] += 1

                        # Фильтр: старый пост (до запуска системы)
                        if startup_time:
                            from datetime import timezone as _tz
                            post_date_utc = post_date.replace(tzinfo=_tz.utc) if post_date.tzinfo is None else post_date
                            startup_utc = startup_time.replace(tzinfo=_tz.utc) if startup_time.tzinfo is None else startup_time
                            if post_date_utc < startup_utc:
                                vk_stats.setdefault("filtered_old", 0)
                                vk_stats["filtered_old"] += 1
                                logger.info(f"⏭️ VK старый пост: {group_id}/{post_id}, дата: {post_date}")
                                continue

                        # Фильтр: короткий текст
                        if len(text.strip()) < MIN_TEXT_LENGTH:
                            vk_stats["filtered_short"] += 1
                            continue

                        # Фильтр: реклама
                        if is_vk_ad(text):
                            vk_stats["filtered_ad"] += 1
                            logger.debug(f"🚫 VK реклама [{name}]: {text[:40]}...")
                            continue

                        # AI анализ
                        logger.info(f"🤖 VK анализ [{name}]: {text[:50]}...")
                        analysis = await analyze_complaint(text)
                        category = analysis.get("category", "Прочее")
                        address = analysis.get("address")
                        summary = analysis.get("summary", text[:100])
                        provider = analysis.get("provider", "?")
                        location_hints = analysis.get("location_hints")

                        # Фильтр: AI решил что не релевантно
                        if not analysis.get("relevant", True):
                            vk_stats["filtered_irrelevant"] += 1
                            logger.info(f"⏭️ VK AI: нерелевантно [{name}] ({category}): {text[:40]}...")
                            continue

                        # Фильтр: keyword-based релевантность
                        if not is_vk_relevant(text, category):
                            vk_stats["filtered_irrelevant"] += 1
                            logger.debug(f"⏭️ VK нерелевантно [{name}] ({category})")
                            continue

                        # Формируем данные жалобы
                        post_link = build_vk_post_link(group_id, post_id)
                        complaint_data = {
                            "text": text,
                            "category": category,
                            "address": address,
                            "summary": summary,
                            "provider": provider,
                            "source": f"vk:{short_name}",
                            "source_name": name,
                            "post_link": post_link,
                            "post_id": post_id,
                            "group_id": group_id,
                            "post_date": post_date.isoformat(),
                            "location_hints": location_hints,
                        }

                        vk_stats["published"] += 1
                        vk_stats["by_group"][name] = vk_stats["by_group"].get(name, 0) + 1

                        logger.info(f"✅ VK [{provider}] {category} из {name} → обработка")

                        if on_complaint:
                            try:
                                await on_complaint(complaint_data)
                            except Exception as e:
                                logger.error(f"Callback error: {e}")
                                vk_stats["errors"] += 1

                    await asyncio.sleep(0.5)  # Rate limit между группами

                except Exception as e:
                    logger.error(f"VK poll error [{name}]: {e}")
                    vk_stats["errors"] += 1

            # Статистика каждые N итераций
            if vk_stats["total"] > 0 and vk_stats["total"] % 20 == 0:
                logger.info(
                    f"📊 VK: всего {vk_stats['total']} | "
                    f"опубликовано {vk_stats['published']} | "
                    f"реклама {vk_stats['filtered_ad']} | "
                    f"нерелевантно {vk_stats['filtered_irrelevant']}"
                )

            await asyncio.sleep(poll_interval)

        except asyncio.CancelledError:
            logger.info("⏹️ VK мониторинг остановлен")
            break
        except Exception as e:
            logger.error(f"VK polling loop error: {e}", exc_info=True)
            await asyncio.sleep(30)

