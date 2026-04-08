 #!/usr/bin/env python3
"""
Единый мониторинг: Telegram каналы + VK паблики → AI → SQLite + @monitornv
"""

import asyncio
import logging
import re
import sys
import os
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Ensure UTF-8 output on Windows consoles
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

from dotenv import load_dotenv
load_dotenv()

from telethon import TelegramClient, events

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Импорты сервисов
from services.zai_service import analyze_complaint, build_marker_summary, make_marker_summary
from services.geo_service import geoparse, sanitize_address_candidate
from services.zai_vision_service import analyze_image_with_glm4v
from services.vk_monitor_service import (
    VK_GROUPS, poll_all_groups, VK_SERVICE_TOKEN,
)
from services.realtime_guard import RealtimeGuard
from services.admin_panel import get_webapp_version

# Telegram config
API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')
PASSWORD_2FA = os.getenv('TG_2FA_PASSWORD', '')
TARGET_CHANNEL = '@monitornv'

# Telegram каналы (из start_monitoring.py)
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

# Фильтры (из start_monitoring.py)
AD_KEYWORDS = [
    "реклама", "промокод", "скидк", "акция", "распродаж", "купи", "закажи",
    "доставк", "интернет-магазин", "подписывайтесь", "подпишись",
    "розыгрыш", "конкурс", "приз", "выигра", "бесплатн", "бонус",
    "кредит", "займ", "ипотек", "инвестиц", "заработ", "доход",
    "казино", "ставк", "букмекер", "тотализатор",
    "знакомств", "свидани", "отношени",
    "гороскоп", "предсказан", "гадани",
    "продаётся", "продается", "сдаётся", "сдается", "аренд", "купить",
    "вакансия", "требуется сотрудник", "ищем работник",
    "taplink", "inst:", "@.*_bot",
]

COMPLAINT_MARKERS = [
    "проблем", "жалоб", "не работает", "сломан", "разбит", "поломк",
    "авари", "прорыв", "прорвал", "затоп", "течь", "течёт", "протечк",
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
]

RELEVANT_CATEGORIES = [
    "ЖКХ", "Дороги", "Благоустройство", "Транспорт", "Экология",
    "Животные", "Безопасность", "Снег/Наледь", "Освещение",
    "Медицина", "Строительство", "Парковки", "ЧП",
    "Газоснабжение", "Водоснабжение и канализация", "Отопление",
    "Бытовой мусор", "Лифты и подъезды", "Парки и скверы",
    "Спортивные площадки", "Детские площадки",
]

MIN_TEXT_LENGTH = 20


def is_ad_or_spam(text: str) -> bool:
    t = text.lower()
    ad_count = sum(1 for kw in AD_KEYWORDS if kw in t)
    if ad_count >= 1 and any(kw in t for kw in [
        "промокод", "розыгрыш", "казино", "букмекер", "гороскоп",
        "продаётся", "продается", "сдаётся", "сдается", "вакансия", "taplink",
    ]):
        return True
    if ad_count >= 2:
        return True
    emoji_count = len(re.findall(r'[\U0001F300-\U0001F9FF]', text))
    if emoji_count > 10 and len(text) < 200:
        return True
    if text.count('#') > 5:
        return True
    return False


def _find_duplicate_report(db, summary, address, lat, lon, category):
    from datetime import datetime, timedelta
    from backend.models import Report

    week_ago = datetime.utcnow() - timedelta(days=7)
    signature = _normalize_text_signature(summary)
    normalized_address = sanitize_address_candidate(address)

    candidates = (
        db.query(Report)
        .filter(
            Report.category == category,
            Report.created_at >= week_ago,
        )
        .order_by(Report.created_at.desc())
        .limit(80)
        .all()
    )

    for report in candidates:
        report_signature = _normalize_text_signature(report.title or report.description)
        report_address = sanitize_address_candidate(report.address)

        matches_coords = _same_coordinates(lat, lon, report.lat, report.lng)
        matches_address = bool(
            normalized_address and report_address and normalized_address == report_address
        )
        matches_signature = bool(
            signature and report_signature and (
                signature == report_signature
                or signature in report_signature
                or report_signature in signature
            )
        )

        if matches_coords and (matches_address or matches_signature or not signature):
            return report
        if matches_address and matches_signature:
            return report

    return None


def has_complaint_markers(text: str) -> bool:
    t = text.lower()
    return any(m in t for m in COMPLAINT_MARKERS)


def is_relevant_message(text: str, category: str) -> bool:
    if len(text.strip()) < MIN_TEXT_LENGTH:
        return False
    if is_ad_or_spam(text):
        return False
    if category in RELEVANT_CATEGORIES:
        return True
    if has_complaint_markers(text):
        return True
    return False


# Общая статистика
stats = {
    'tg_total': 0, 'tg_published': 0, 'tg_filtered': 0,
    'vk_total': 0, 'vk_published': 0, 'vk_filtered': 0,
    
    'by_category': {},
}

# RealtimeGuard — инициализируется в main()
guard: RealtimeGuard = None


def _normalize_text_signature(text: str | None) -> str:
    cleaned = make_marker_summary(text, max_len=120).lower()
    cleaned = re.sub(r"[^a-zа-яё0-9\s]", " ", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned


def _same_coordinates(lat1, lng1, lat2, lng2) -> bool:
    if None in (lat1, lng1, lat2, lng2):
        return False
    return abs(float(lat1) - float(lat2)) <= 0.0009 and abs(float(lng1) - float(lng2)) <= 0.0012


def _check_duplicate(db, text, address, lat, lon, category):
    """Проверяет дубликаты жалоб по тексту, адресу и координатам"""
    from sqlalchemy import func, and_
    from backend.models import Report
    from datetime import datetime, timedelta
    
    # Проверка за последние 7 дней
    week_ago = datetime.utcnow() - timedelta(days=7)
    
    def _escape_like(s: str) -> str:
        """Escape special LIKE characters to prevent unintended matching."""
        return s.replace("%", "\\%").replace("_", "\\_")
    
    # По координатам (если есть)
    if lat and lon:
        # Радиус ~100 метров
        lat_diff = 0.0009  # ~100м
        lon_diff = 0.0012  # ~100м
        similar_coords = db.query(Report).filter(
            and_(
                Report.lat.between(lat - lat_diff, lat + lat_diff),
                Report.lng.between(lon - lon_diff, lon + lon_diff),
                Report.category == category,
                Report.created_at >= week_ago
            )
        ).first()
        if similar_coords:
            return True
    
    # По адресу (если есть)
    if address:
        addr_normalized = _escape_like(address.lower().strip()[:30])
        similar_addr = db.query(Report).filter(
            and_(
                func.lower(Report.address).like("%" + addr_normalized + "%"),
                Report.category == category,
                Report.created_at >= week_ago
            )
        ).first()
        if similar_addr:
            return True
    
    # По тексту (первые 50 символов)
    if text and len(text) > 20:
        text_snippet = _escape_like(text[:50].lower().strip())
        similar_text = db.query(Report).filter(
            and_(
                func.lower(Report.description).like("%" + text_snippet + "%"),
                Report.category == category,
                Report.created_at >= week_ago
            )
        ).first()
        if similar_text:
            return True
    
    return False


async def save_to_db(summary, text, lat, lng, address, category, source, msg_id=None, channel=None):
    """Сохраняет жалобу в SQLite с проверкой дубликатов"""
    db = None
    try:
        from backend.database import SessionLocal
        from backend.models import Report
        db = SessionLocal()
        
        # Проверка дубликатов
        if _check_duplicate(db, text, address, lat, lng, category):
            logger.info(f"⏭️ Дубликат пропущен: {category} @ {address or f'{lat},{lng}'}")
            return None
        
        report = Report(
            title=summary[:200],
            description=text[:2000],
            lat=lat, lng=lng,
            address=address,
            category=category,
            status="open",
            source=source,
            telegram_message_id=str(msg_id) if msg_id else None,
            telegram_channel=channel,
        )
        db.add(report)
        db.commit()
        report_id = report.id
        return report_id
    except Exception as e:
        logger.error(f"DB error: {e}")
        return None
    finally:
        if db is not None:
            db.close()


def _truncate_summary(summary: str, max_len: int = 150) -> str:
    """Обрезает сводку до max_len символов. В служебный канал — только краткая сводка, не весь пост."""
    if not summary or len(summary) <= max_len:
        return summary or ""
    return summary[: max_len - 3].rstrip() + "..."


def _get_source_icon(source_label, source_link):
    """Возвращает иконку соцсети для источника"""
    source_lower = source_label.lower()
    if "telegram" in source_lower or "tg:" in source_lower or source_link.startswith("https://t.me"):
        return "🔵"  # Telegram
    elif "vk" in source_lower or "vkontakte" in source_lower or "vk.com" in source_link:
        return "🔷"  # VK
    elif "instagram" in source_lower or "inst" in source_lower:
        return "📷"  # Instagram
    elif "facebook" in source_lower or "fb" in source_lower:
        return "📘"  # Facebook
    elif "twitter" in source_lower or "x.com" in source_lower:
        return "🐦"  # Twitter/X
    else:
        return "📢"  # Общая иконка


async def _check_duplicate_post(client, summary, address, lat, lon, category):
    """Проверяет дубликаты постов в канале перед публикацией"""
    try:
        from datetime import datetime
        # Получаем последние сообщения из канала (за последние 24 часа)
        messages = await client.get_messages(TARGET_CHANNEL, limit=50)
        now = datetime.now()
        
        for msg in messages:
            if not msg.text:
                continue
            
            # Проверка по тексту сводки
            if summary and summary[:50].lower() in msg.text.lower():
                return True
            
            # Проверка по адресу
            if address and address.lower() in msg.text.lower():
                return True
            
            # Проверка по координатам (если есть)
            if lat and lon:
                coord_str = f"{lat:.4f}, {lon:.4f}"
                if coord_str in msg.text or f"{lat:.3f}" in msg.text:
                    return True
        
        return False
    except Exception as e:
        logger.debug(f"Duplicate check error: {e}")
        return False


async def publish_to_telegram(client, category, report_id, summary, address, lat, lon, source_label, source_link, timestamp, geo_accuracy=None):
    """Публикует проблему в @monitornv с иконками соцсетей и ссылкой на маркер карты"""
    # Проверка дубликатов перед публикацией
    if await _check_duplicate_post(client, summary, address, lat, lon, category):
        logger.info(f"⏭️ Дубликат поста пропущен: {category} @ {address or f'{lat},{lon}'}")
        return False
    
    summary = _truncate_summary(summary, 500)  # Increase limit for deep analysis
    emoji = EMOJI.get(category, "❔")
    tag = TAG.get(category, category.replace(" ", "_"))
    source_icon = _get_source_icon(source_label, source_link)

    lines = [f"{emoji} {category}"]
    if report_id:
        lines[0] += f" #{report_id}"
    lines.append("")
    lines.append(f"<b>Описание:</b>\n{summary}")
    
    # Публикуем адрес и карту ТОЛЬКО если уверены на 100% (geo_accuracy == "high")
    if geo_accuracy == "high" and address:
        lines.append("")
        lines.append(f"📍 <b>Адрес:</b> {address}")
        
        if lat and lon:
            lines.append(f"🗺️ {lat:.4f}, {lon:.4f}")
            sv_url = f"https://www.google.com/maps/@?api=1&map_action=pano&viewpoint={lat},{lon}&heading=0&pitch=0&fov=90"
            map_url = f"https://www.google.com/maps/search/?api=1&query={lat},{lon}"
            
            from core.config import PUBLIC_API_BASE_URL
            version = get_webapp_version()
            map_marker_url = f"{PUBLIC_API_BASE_URL}/map?v={version}&marker={lat},{lon}"
            
            map_links = f'👁 <a href="{sv_url}">Street View</a> | 📌 <a href="{map_url}">Google Maps</a>'
            map_links += f' | 🗺️ <a href="{map_marker_url}">На карте</a>'
            lines.append(map_links)
    
    lines.append("")
    # Источник с иконкой
    lines.append(f"{source_icon} <a href=\"{source_link}\">{source_label}</a>")
    lines.append(f"🕐 {timestamp}")
    lines.append("")
    lines.append(f"#ГородскаяПроблема #{tag} #Нижневартовск")

    post_text = "\n".join(lines)
    try:
        await client.send_message(TARGET_CHANNEL, post_text, parse_mode='html')
        return True
    except Exception as e:
        logger.error(f"❌ Публикация TG: {e}")
        return False


async def process_complaint(client, text, category, address, summary, provider, source, source_label, source_link, msg_id=None, channel=None, location_hints=None, exif_lat=None, exif_lon=None):
    """Единая обработка: EXIF GPS / геопарсинг → SQLite → Telegram"""
    # Приоритет: EXIF GPS → geoparse (AI адрес → парсер → ориентиры → hints)
    lat, lon = None, None
    if exif_lat and exif_lon:
        lat, lon = exif_lat, exif_lon
        # Обратное геокодирование если нет адреса
        if not address:
            try:
                from services.geo_service import reverse_geocode
                rev_addr = await reverse_geocode(exif_lat, exif_lon)
                if rev_addr:
                    address = rev_addr
            except Exception:
                pass
    else:
        geo = await geoparse(text, ai_address=address, location_hints=location_hints)
        lat = geo.get("lat")
        lon = geo.get("lng")
        if geo.get("address"):
            address = geo["address"]

    # SQLite
    report_id = await save_to_db(summary, text, lat, lon, address, category, source, msg_id, channel)

    # Определяем точность геолокации
    geo_accuracy = None
    if lat and lon:
        if exif_lat and exif_lon:
            geo_accuracy = "high"  # EXIF GPS = 100% точность
        elif address and len(address.split()) >= 3:  # Полный адрес с домом
            geo_accuracy = "high"
        else:
            geo_accuracy = "medium"
    
    # Telegram @monitornv
    timestamp = datetime.now().strftime('%d.%m.%Y %H:%M')
    published = await publish_to_telegram(
        client, category, report_id, summary, address, lat, lon,
        source_label, source_link, timestamp, geo_accuracy=geo_accuracy
    )

    # Push-уведомления подписчикам по геозонам
    if lat and lon and report_id:
        try:
            from services.push_notification_service import notify_subscribers
            await notify_subscribers(
                lat=lat, lng=lon,
                category=category,
                summary=summary,
                address=address,
                report_id=report_id,
            )
        except Exception as push_err:
            logger.debug("Push notification error: %s", push_err)

    stats['by_category'][category] = stats['by_category'].get(category, 0) + 1
    return published


async def save_to_db(summary, text, lat, lng, address, category, source, msg_id=None, channel=None):
    """Save complaint marker payload and merge repeated public complaints into one report."""
    db = None
    try:
        from backend.database import SessionLocal
        from backend.models import Report

        db = SessionLocal()
        marker_summary = build_marker_summary(summary, text, max_len=120)
        normalized_address = sanitize_address_candidate(address) or address
        duplicate = _find_duplicate_report(
            db,
            marker_summary or text,
            normalized_address,
            lat,
            lng,
            category,
        )
        if duplicate:
            changed = False
            short_title = (marker_summary or summary or text or "")[:200]
            short_description = (marker_summary or summary or text or "")[:400]
            if short_title and duplicate.title != short_title:
                duplicate.title = short_title
                changed = True
            if short_description and duplicate.description != short_description:
                duplicate.description = short_description
                changed = True
            if normalized_address and duplicate.address != normalized_address:
                duplicate.address = normalized_address
                changed = True
            if lat is not None and duplicate.lat is None:
                duplicate.lat = lat
                changed = True
            if lng is not None and duplicate.lng is None:
                duplicate.lng = lng
                changed = True
            if changed:
                db.commit()
            logger.info(
                "Duplicate complaint merged into report %s for %s @ %s",
                duplicate.id,
                category,
                normalized_address or f"{lat},{lng}",
            )
            return duplicate.id, False

        report = Report(
            title=(marker_summary or summary or text or "")[:200],
            description=(marker_summary or summary or text or "")[:400],
            lat=lat,
            lng=lng,
            address=normalized_address,
            category=category,
            status="open",
            source=source,
            telegram_message_id=str(msg_id) if msg_id else None,
            telegram_channel=channel,
        )
        db.add(report)
        db.commit()
        return report.id, True
    except Exception as e:
        logger.error(f"DB error: {e}")
        return None, False
    finally:
        if db is not None:
            db.close()


def _has_concrete_address(address: str | None) -> bool:
    """Check if address contains a VALID street name + house number.

    СТРОГИЕ ПРАВИЛА:
    - Должен быть маркер улицы (ул., улица, пр., проспект и т.д.) ИЛИ известная улица Нижневартовска
    - Должен быть номер дома (1-3 цифры, возможно с буквой)
    - Адрес должен содержать минимум 2 слова (улица + номер считаются)
    - Отклоняем адреса без маркера улицы, если это не известная улица города
    """
    if not address:
        return False
    import re

    cleaned = address.strip().rstrip(",")
    if not cleaned:
        return False

    # 1. Маркер улицы/проспекта/переулка и т.д.
    has_street = bool(re.search(
        r'(?:ул\.?|улица|пр\.?|проспект|пер\.?|переулок|б-р|бульвар|мкр\.?|микрорайон|наб\.?|набережная)',
        cleaned, re.IGNORECASE
    ))

    # 2. Известные улицы Нижневартовска (без маркера тоже принимаем)
    has_known_street = any(hint in cleaned.lower() for hint in (
        'мира', 'ленина', 'пионерская', 'омская', 'чапаева', 'интернациональная',
        'нефтяников', 'дружбы народов', 'северная', 'маршала жукова', 'спортивная',
        'таежная', 'мусы джалиля', 'ханты-мансийская', '60 лет октября',
        'индустриальная', 'рабочая', 'кузоваткина', 'авиаторов',
    ))

    # 3. Номер дома: 1-3 цифры, опционально с буквой (1а, 15б, 120)
    has_house = bool(re.search(r'(?:^|[\s,])\d{1,3}[а-яА-Яa-zA-Z]?(?:[\s,/]|$)', cleaned))

    # 4. Минимальная длина: адрес должен содержать хотя бы улицу + номер
    words = [w for w in cleaned.split() if len(w) > 1]
    has_min_length = len(words) >= 2

    # СТРОГО: требуем И маркер улицы (или известную улицу), И номер дома, И минимальную длину
    if not has_house:
        return False
    if not has_min_length:
        return False
    if not (has_street or has_known_street):
        return False

    # Отклоняем подозрительные адреса
    lower = cleaned.lower()
    suspicious_patterns = [
        'где-то', 'где то', 'примерно', 'около', 'возле', 'рядом',
        'недалеко от', 'напротив', 'за', 'у', 'рядом с',
    ]
    # Если адрес состоит ТОЛЬКО из подозрительных слов без конкретной улицы — отклоняем
    if not has_street and not has_known_street:
        return False

    return True


async def process_complaint(client, text, category, address, summary, provider, source, source_label, source_link, msg_id=None, channel=None, location_hints=None, exif_lat=None, exif_lon=None):
    """Unified complaint pipeline with deduplicated marker creation."""
    lat, lon = None, None
    if exif_lat and exif_lon:
        lat, lon = exif_lat, exif_lon
        if not address:
            try:
                from services.geo_service import reverse_geocode

                rev_addr = await reverse_geocode(exif_lat, exif_lon)
                if rev_addr:
                    address = rev_addr
            except Exception:
                pass
    else:
        geo = await geoparse(text, ai_address=address, location_hints=location_hints)
        lat = geo.get("lat")
        lon = geo.get("lng")
        if geo.get("address"):
            address = geo["address"]

    marker_summary = build_marker_summary(summary, text, max_len=120)

    # === ADDRESS GATE: без конкретного адреса (улица + дом) — не маркируем и не публикуем ===
    if not _has_concrete_address(address):
        logger.info(
            "⏭️ Нет конкретного адреса — пропуск маркировки: %s | addr=%s | %s",
            category, address, source_label,
        )
        stats['by_category'][category] = stats['by_category'].get(category, 0) + 1
        return False

    report_id, is_new_report = await save_to_db(
        marker_summary,
        text,
        lat,
        lon,
        address,
        category,
        source,
        msg_id,
        channel,
    )

    geo_accuracy = None
    if lat and lon:
        if exif_lat and exif_lon and _has_concrete_address(address):
            geo_accuracy = "high"
        elif _has_concrete_address(address) and address and len(address.split()) >= 3:
            geo_accuracy = "high"
        else:
            geo_accuracy = "medium"
    elif _has_concrete_address(address):
        # Координат нет, но адрес конкретный — всё равно high
        geo_accuracy = "high"

    timestamp = datetime.now().strftime('%d.%m.%Y %H:%M')
    published = False

    # ПУБЛИКАЦИЯ ТОЛЬКО С ВЫСОКОЙ ТОЧНОСТЬЮ АДРЕСА
    if geo_accuracy != "high":
        logger.info(
            "⏭️ geo_accuracy=%s — публикация в канал пропущена: %s @ %s",
            geo_accuracy, category, address or f"{lat},{lon}",
        )
    elif is_new_report:
        published = await publish_to_telegram(
            client,
            category,
            report_id,
            marker_summary,
            address,
            lat,
            lon,
            source_label,
            source_link,
            timestamp,
            geo_accuracy=geo_accuracy,
        )
    else:
        logger.info(
            "Repeated complaint skipped for public marker creation: %s @ %s",
            category,
            address or f"{lat},{lon}",
        )

    if is_new_report and lat and lon and report_id:
        try:
            from services.push_notification_service import notify_subscribers

            await notify_subscribers(
                lat=lat,
                lng=lon,
                category=category,
                summary=marker_summary,
                address=address,
                report_id=report_id,
            )
        except Exception as push_err:
            logger.debug("Push notification error: %s", push_err)

    stats['by_category'][category] = stats['by_category'].get(category, 0) + 1
    return published


# ============================================================
# TELEGRAM MONITORING
# ============================================================

async def handle_telegram_message(client, event):
    """Обработчик новых сообщений из TG каналов (текст + фото)"""
    try:
        # RealtimeGuard: проверка таймстемпа
        if guard:
            msg_time = event.message.date
            if not guard.is_new_message(msg_time):
                channel = event.chat.username or ""
                logger.info(f"⏭️ Старое сообщение: @{channel}/{event.message.id}, время: {msg_time}")
                return

            source = f"tg:{event.chat.username or ''}"
            if guard.is_duplicate(source, event.message.id):
                logger.debug(f"⏭️ Дубликат: {source}/{event.message.id}")
                return

        text = event.message.text or event.message.message or ""
        channel_username = event.chat.username or ""
        channel_title = event.chat.title or channel_username
        message_id = event.message.id
        msg_link = f"https://t.me/{channel_username}/{message_id}"

        # Обработка фото с подписью
        photo_result = None
        if event.message.photo:
            try:
                import tempfile
                tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
                await client.download_media(event.message, file=tmp.name)
                tmp.close()
                caption = event.message.message or ""
                photo_result = await analyze_image_with_glm4v(tmp.name, caption)
                import os as _os
                _os.unlink(tmp.name)
                # text по‑прежнему нужен для базы и дальнейшей обработки,
                # но в служебный канал мы шлём только аналитическое summary,
                # поэтому НЕ дублируем сюда сырой текст.
                if not text:
                    text = caption or photo_result.get("description", "")
            except Exception as e:
                logger.error(f"Photo download/analysis error: {e}")

        if not text or len(text.strip()) < MIN_TEXT_LENGTH:
            return

        stats['tg_total'] += 1

        if is_ad_or_spam(text):
            stats['tg_filtered'] += 1
            return

        # Если есть результат анализа фото — используем его
        if photo_result:
            category = photo_result.get('category', 'Прочее')
            address = photo_result.get('address')
            # В служебный канал отправляем только анализ (описание от модели),
            # без прямого копирования текста жалобы.
            raw_desc = photo_result.get('description')
            if raw_desc:
                summary = raw_desc
            else:
                summary = f"Проблема ({category}): требуется проверка по фото из канала."
            provider = photo_result.get('provider', '?')
            location_hints = photo_result.get('location_hints')
            exif_lat = photo_result.get('exif_lat')
            exif_lon = photo_result.get('exif_lon')
            has_vehicle = photo_result.get('has_vehicle_violation', False)
            plates = photo_result.get('plates')

            if has_vehicle and plates:
                summary = f"🚗 Нарушение парковки ({plates}). {summary}"
            elif has_vehicle:
                summary = f"🚗 Нарушение парковки. {summary}"
        else:
            # Текстовый анализ
            analysis = await analyze_complaint(text)
            category = analysis.get('category', 'Прочее')
            address = analysis.get('address')
            summary = analysis.get('summary', text[:100])
            provider = analysis.get('provider', '?')
            location_hints = analysis.get('location_hints')
            exif_lat = None
            exif_lon = None

            # AI фильтрация
            if not analysis.get('relevant', True):
                stats['tg_filtered'] += 1
                logger.info(f"⏭️ AI: нерелевантно [{provider}] из @{channel_username}: {text[:40]}...")
                return

        if not is_relevant_message(text, category):
            stats['tg_filtered'] += 1
            return

        # Если есть EXIF координаты — передаём их напрямую в process_complaint
        published = await process_complaint(
            client, text, category, address, summary, provider,
            source=f"tg:@{channel_username}",
            source_label=f"@{channel_username}",
            source_link=msg_link,
            msg_id=message_id,
            channel=f"@{channel_username}",
            location_hints=location_hints,
            exif_lat=exif_lat,
            exif_lon=exif_lon,
        )
        if published:
            stats['tg_published'] += 1
            logger.info(f"✅ TG [{provider}] {category} из @{channel_username} (Городская проблема)")

        # RealtimeGuard: отмечаем как обработанное
        if guard:
            guard.mark_processed(f"tg:{channel_username}", message_id)

    except Exception as e:
        logger.error(f"❌ TG handler error: {e}", exc_info=True)



# ============================================================
# VK MONITORING CALLBACK
# ============================================================

async def handle_vk_complaint(client, complaint_data: dict):
    """Callback для VK мониторинга — обрабатывает найденную жалобу"""
    stats['vk_total'] += 1

    published = await process_complaint(
        client,
        text=complaint_data["text"],
        category=complaint_data["category"],
        address=complaint_data.get("address"),
        summary=complaint_data["summary"],
        provider=complaint_data.get("provider", "?"),
        source=complaint_data["source"],
        source_label=complaint_data["source_name"],
        source_link=complaint_data["post_link"],
        location_hints=complaint_data.get("location_hints"),
    )
    if published:
        stats['vk_published'] += 1
        logger.info(f"✅ VK [{complaint_data.get('provider')}] {complaint_data['category']} из {complaint_data['source_name']}")


# ============================================================
# MAIN
# ============================================================

async def main():
    global guard
    logger.info("=" * 60)
    logger.info("🚀 ЕДИНЫЙ МОНИТОРИНГ: Telegram + VK → AI → SQLite + @monitornv")
    logger.info("=" * 60)

    if not API_ID or not API_HASH:
        logger.error("❌ TG_API_ID или TG_API_HASH не найдены в .env")
        return

    # Инициализация RealtimeGuard
    guard = RealtimeGuard()
    logger.info(f"⏱️ Время запуска (UTC): {guard.startup_time.isoformat()}")
    logger.info("🛡️ RealtimeGuard: только новые сообщения + дедупликация")

    client = TelegramClient('monitoring_session', API_ID, API_HASH)
    vk_task = None

    try:
        # Если сессия валидна — подключится без ввода кода
        # Если нет — запустите сначала: py auth_telethon.py
        await client.connect()
        if not await client.is_user_authorized():
            logger.warning("⚠️ Сессия не авторизована! Запустите: py auth_telethon.py")
            logger.error(
                "❌ Headless-режим не может запросить код Telegram. "
                "Нужен готовый monitoring_session.session на хосте."
            )
            await asyncio.Event().wait()
        logger.info("✅ Telegram подключён")

        me = await client.get_me()
        logger.info(f"👤 {me.first_name} (@{me.username})")

        # Проверяем целевой канал
        if TARGET_CHANNEL:
            try:
                ch = await client.get_entity(TARGET_CHANNEL)
                logger.info(f"✅ Целевой канал: {ch.title}")
            except Exception as e:
                logger.error(f"❌ Канал {TARGET_CHANNEL}: {e}")

        # --- Telegram мониторинг ---
        logger.info(f"\n📡 TELEGRAM: {len(CHANNELS_TO_MONITOR)} каналов")
        for c in CHANNELS_TO_MONITOR:
            logger.info(f"   • {c}")

        @client.on(events.NewMessage(chats=CHANNELS_TO_MONITOR))
        async def tg_handler(event):
            await handle_telegram_message(client, event)
            _print_stats_periodic()

        # --- VK мониторинг ---
        if VK_SERVICE_TOKEN:
            logger.info(f"\n🔵 VK: {len(VK_GROUPS)} пабликов")
            for short_name, gid, name in VK_GROUPS:
                logger.info(f"   • {name}")

            async def vk_callback(complaint_data):
                await handle_vk_complaint(client, complaint_data)

            vk_task = asyncio.create_task(
                poll_all_groups(on_complaint=vk_callback, poll_interval=120, startup_time=guard.startup_time)
            )
            logger.info("✅ VK polling запущен (интервал 2 мин)")
        else:
            logger.warning("⚠️ VK_SERVICE_TOKEN не задан — VK мониторинг отключён")
            logger.warning("   Получите токен: https://dev.vk.com → Мои приложения → Сервисный ключ")
            vk_task = None

        # Data storage: SQLite + PostgreSQL runtime
        logger.info("✅ Данные сохраняются в SQLite + PostgreSQL runtime")

        logger.info("\n" + "=" * 60)
        logger.info("🤖 Мониторинг запущен! Ожидание сообщений...")
        logger.info("⏹️  Ctrl+C для остановки")
        logger.info("=" * 60)

        await client.run_until_disconnected()

    except KeyboardInterrupt:
        logger.info("⏹️ Остановка...")
    except Exception as e:
        logger.error(f"❌ {e}", exc_info=True)
    finally:
        _print_final_stats()
        if vk_task is not None:
            vk_task.cancel()
        await client.disconnect()


_stats_counter = 0

def _print_stats_periodic():
    global _stats_counter
    _stats_counter += 1
    if _stats_counter % 10 == 0:
        total = stats['tg_total'] + stats['vk_total']
        published = stats['tg_published'] + stats['vk_published']
        gs = guard.stats if guard else None
        guard_info = f" | 🛡️ Старые: {gs.skipped_old} Дубли: {gs.skipped_duplicate}" if gs else ""
        logger.info(
            f"📊 TG: {stats['tg_published']}/{stats['tg_total']} | "
            f"VK: {stats['vk_published']}/{stats['vk_total']} | "
            ""
            f"Всего: {published}/{total}{guard_info}"
        )


def _print_final_stats():
    total = stats['tg_total'] + stats['vk_total']
    published = stats['tg_published'] + stats['vk_published']
    logger.info("\n📊 ИТОГО:")
    logger.info(f"   Telegram: {stats['tg_published']}/{stats['tg_total']} опубликовано")
    logger.info(f"   VK: {stats['vk_published']}/{stats['vk_total']} опубликовано")
    logger.info(f"   Всего: {published}/{total}")
    for cat, cnt in sorted(stats['by_category'].items(), key=lambda x: x[1], reverse=True):
        logger.info(f"   {EMOJI.get(cat, '❔')} {cat}: {cnt}")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("⏹️ Мониторинг остановлен")
