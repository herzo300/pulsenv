import logging
import re
from typing import Any

from dotenv import load_dotenv

# Load .env from project root
load_dotenv()

logger = logging.getLogger(__name__)

# Nominatim for geocoding
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
DEFAULT_LAT = 60.9692
DEFAULT_LNG = 76.5314
DEFAULT_ADDRESS = "Нижневартовск памятник Алеша"

# Categories for keyword matching
CATEGORY_KEYWORDS = {
    "Дороги": ["яма", "дорог", "асфальт", "тротуар", "выбоин", "колея", "светофор"],
    "ЖКХ": ["жкх", "управляющ", "коммунал", "квитанц", "тариф", "подъезд"],
    "Освещение": ["фонар", "освещен", "свет не гор", "темно", "лампа"],
    "Транспорт": ["автобус", "маршрут", "транспорт", "остановк", "парков"],
    "Экология": ["эколог", "загрязн", "выброс", "запах", "мусор", "свалк"],
    "Безопасность": ["полиц", "кража", "вандал", "камер", "охрана"],
    "Снег/Наледь": ["снег", "налед", "гололёд", "гололед", "сугроб"],
    "Отопление": ["отоплен", "батаре", "холодн", "не греет"],
    "Водоснабжение и канализация": ["канализ", "труб", "течь", "затоп", "прорыв"],
    "Благоустройство": ["двор", "клумб", "газон", "лавочк", "сквер", "парк"],
}


def _extract_address_from_text(text: str) -> str | None:
    """Извлечь адрес из текста сообщения"""
    patterns = [
        r"ул\.?\s+([А-Яа-яЁё]+)\s*,?\s*(\d+[а-яА-Я]?)",
        r"улица\s+([А-Яа-яЁё]+)\s*,?\s*(\d+[а-яА-Я]?)",
        r"пр-?кт\.?\s+([А-Яа-яЁё]+)\s*,?\s*(\d+[а-яА-Я]?)",
        r"проспект\s+([А-Яа-яЁё]+)\s*,?\s*(\d+[а-яА-Я]?)",
        r"пер\.?\s+([А-Яа-яЁё]+)\s*,?\s*(\d+[а-яА-Я]?)",
        r"переулок\s+([А-Яа-я�ё]+)\s*,?\s*(\d+[а-яА-Я]?)",
        r"мкр\.?\s+(\d+[а-яА-Я]?)\s*,?\s*д\.?\s*(\d+)",
        r"микрорайон\s+(\d+)\s*,?\s*дом\s+(\d+)",
    ]

    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            parts = [g for g in match.groups() if g]
            return " ".join(parts) + ", Нижневартовск"

    return None


def _extract_category_from_text(text: str) -> str:
    """Определить категорию по ключевым словам"""
    text_lower = text.lower()

    for category, keywords in CATEGORY_KEYWORDS.items():
        for keyword in keywords:
            if keyword in text_lower:
                return category

    return "Прочее"


async def nominatim_geocode(address: str) -> tuple[float, float]:
    """Геокодинг адреса через Nominatim с учетом правил размещения"""
    if not address or address in ["Нижневартовск центр", "Нижневартовск памятник Алеша"]:
        return DEFAULT_LAT, DEFAULT_LNG

    addr_lower = address.lower()
    
    # 1. Река: если про реку, то на реке обь рядом с городом
    if any(w in addr_lower for w in ["обь", "река", "реке", "набережная", "набережной", "пляж"]):
        logger.info(f"Geocoding: River Ob match for address '{address}'")
        return 60.9250, 76.5700
        
    # 2. Парк: если в парке, то в центре парка
    if any(w in addr_lower for w in ["парк", "парке", "сквер", "сквере"]):
        logger.info(f"Geocoding: Park match for address '{address}'")
        return 60.9322, 76.5642
        
    # 3. Общее про город: если общее про город, размещай на памятнике алеша
    if addr_lower in ["нижневартовск", "нижневартовск центр", "город", "прочее"]:
        logger.info(f"Geocoding: General city match (Alyosha) for address '{address}'")
        return DEFAULT_LAT, DEFAULT_LNG

    try:
        import httpx

        params = {
            "q": f"Нижневартовск {address}",
            "format": "json",
            "limit": 1,
            "accept-language": "ru",
        }
        headers = {"User-Agent": "Soobshio/1.0 (City Complaint System)"}

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(NOMINATIM_URL, params=params, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                if data:
                    return float(data[0]["lat"]), float(data[0]["lon"])
    except Exception as e:
        logger.warning(f"Nominatim geocoding failed: {e}")

    return DEFAULT_LAT, DEFAULT_LNG


async def analyze_with_ai(text: str) -> dict[str, Any]:
    """AI анализ через OpenRouter (qwen) с fallback на keyword"""
    from services.ai.zai_service import analyze_complaint

    try:
        result = await analyze_complaint(text)
        if result and result.get("category"):
            return result
    except Exception as e:
        logger.warning(f"AI analysis failed: {e}")

    # Keyword fallback
    category = _extract_category_from_text(text)
    address = _extract_address_from_text(text)
    if address is None:
        d = district_from_text(text)
        if d:
            return {"lat": d[0], "lng": d[1], "address": d[2],
                    "category": _extract_category_from_text(text), "raw": text}

    return {
        "category": category,
        "address": address,
        "summary": text[:100] if len(text) > 100 else text,
        "relevant": True,
        "provider": "keyword",
    }


async def claude_geoparse(text: str) -> tuple[float, float, str]:
    """
    Полный анализ жалобы: AI категоризация + геокодинг
    Returns: (lat, lng, address)
    """
    logger.info(f"Processing complaint: {text[:50]}...")

    # 1. AI анализ (или keyword fallback)
    try:
        ai_result = await analyze_with_ai(text)
    except Exception as e:
        logger.error(f"AI analysis error: {e}")
        ai_result = {
            "category": _extract_category_from_text(text),
            "address": _extract_address_from_text(text),
            "summary": text[:100],
        }

    # 2. Извлекаем адрес
    address = ai_result.get("address")
    if not address:
        address = _extract_address_from_text(text)

    # 3. Если адреса нет - используем категорию для поиска
    if not address:
        category = ai_result.get("category", "Прочее")
        if category != "Прочее":
            address = category
        else:
            address = DEFAULT_ADDRESS

    # 4. Геокодинг с приоритетом правил по тексту сообщения
    text_lower = text.lower()
    if any(w in text_lower for w in ["обь", "река", "реке", "набережная", "набережной", "пляж"]):
        lat, lng = 60.9250, 76.5700
        if not address or address == DEFAULT_ADDRESS:
            address = "река Обь"
    elif any(w in text_lower for w in ["парк", "парке", "сквер", "сквере"]):
        lat, lng = 60.9322, 76.5642
        if not address or address == DEFAULT_ADDRESS:
            address = "городской парк"
    else:
        lat, lng = await nominatim_geocode(address)

    logger.info(f"Geoparse result: {address} -> [{lat}, {lng}]")

    return lat, lng, address


async def parse_complaint_with_ai(text: str) -> dict[str, Any]:
    """Полный анализ жалобы с AI и геокодингом"""
    # AI анализ
    ai_result = await analyze_with_ai(text)

    # Извлекаем адрес
    address = ai_result.get("address")
    if not address:
        address = _extract_address_from_text(text)

    # Геокодинг с приоритетом правил по тексту сообщения
    text_lower = text.lower()
    if any(w in text_lower for w in ["обь", "река", "реке", "набережная", "набережной", "пляж"]):
        lat, lng = 60.9250, 76.5700
        if not address:
            address = "река Обь"
    elif any(w in text_lower for w in ["парк", "парке", "сквер", "сквере"]):
        lat, lng = 60.9322, 76.5642
        if not address:
            address = "городской парк"
    else:
        lat, lng = await nominatim_geocode(
            address if address else ai_result.get("category", "Прочее")
        )

    return {
        "category": ai_result.get("category", "Прочее"),
        "lat": lat,
        "lng": lng,
        "address": address or DEFAULT_ADDRESS,
        "summary": ai_result.get("summary", text[:100]),
        "relevant": ai_result.get("relevant", True),
        "provider": ai_result.get("provider", "unknown"),
    }



# Районные якоря НВ (фолбэк, когда нет конкретного адреса)
_DISTRICT_ANCHORS = [
    (("жд", "вокзал", "железнодорожн"), 60.9385, 76.5620, "ЖД район"),
    (("аэропорт",), 60.9044, 76.5630, "Аэропорт"),
    (("самотлор",), 60.9230, 76.4830, "Посёлок Самотлор"),
    (("нововартовск",), 60.9480, 76.6300, "Нововартовск"),
    (("затон", "речпорт", "порт"), 60.9260, 76.5760, "Затон"),
    (("промзона", "промышленн"), 60.9460, 76.5400, "Промзона"),
]


def district_from_text(text):
    """Район по упоминанию: «возле жд» -> координаты ЖД-района."""
    low = (text or "").lower()
    for kws, lat, lng, name in _DISTRICT_ANCHORS:
        for kw in kws:
            if kw in low:
                return lat, lng, name
    return None
