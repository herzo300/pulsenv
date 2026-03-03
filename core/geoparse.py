import re
import logging
from typing import Tuple, Optional, Dict, Any
from dotenv import load_dotenv

# Load .env from project root
load_dotenv()

logger = logging.getLogger(__name__)

# Nominatim for geocoding
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
DEFAULT_LAT = 60.9344
DEFAULT_LNG = 76.5531
DEFAULT_ADDRESS = "Нижневартовск центр"

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


def _extract_address_from_text(text: str) -> Optional[str]:
    """Извлечь адрес из текста сообщения"""
    patterns = [
        r'ул\.?\s+([А-Яа-яЁё]+)\s*,?\s*(\d+[а-яА-Я]?)',
        r'улица\s+([А-Яа-яЁё]+)\s*,?\s*(\d+[а-яА-Я]?)',
        r'пр-?кт\.?\s+([А-Яа-яЁё]+)\s*,?\s*(\d+[а-яА-Я]?)',
        r'проспект\s+([А-Яа-яЁё]+)\s*,?\s*(\d+[а-яА-Я]?)',
        r'пер\.?\s+([А-Яа-яЁё]+)\s*,?\s*(\d+[а-яА-Я]?)',
        r'переулок\s+([А-Яа-я�ё]+)\s*,?\s*(\d+[а-яА-Я]?)',
        r'мкр\.?\s+(\d+[а-яА-Я]?)\s*,?\s*д\.?\s*(\d+)',
        r'микрорайон\s+(\d+)\s*,?\s*дом\s+(\d+)',
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


async def nominatim_geocode(address: str) -> Tuple[float, float]:
    """Геокодинг адреса через Nominatim"""
    if not address or address == "Нижневартовск центр":
        return DEFAULT_LAT, DEFAULT_LNG
    
    try:
        import httpx
        params = {
            'q': f"Нижневартовск {address}",
            'format': 'json',
            'limit': 1,
            'accept-language': 'ru'
        }
        headers = {'User-Agent': 'Soobshio/1.0 (City Complaint System)'}
        
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(NOMINATIM_URL, params=params, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                if data:
                    return float(data[0]['lat']), float(data[0]['lon'])
    except Exception as e:
        logger.warning(f"Nominatim geocoding failed: {e}")
    
    return DEFAULT_LAT, DEFAULT_LNG


async def analyze_with_ai(text: str) -> Dict[str, Any]:
    """AI анализ через OpenRouter (qwen) с fallback на keyword"""
    from services.zai_service import analyze_complaint
    
    try:
        result = await analyze_complaint(text)
        if result and result.get('category'):
            return result
    except Exception as e:
        logger.warning(f"AI analysis failed: {e}")
    
    # Keyword fallback
    category = _extract_category_from_text(text)
    address = _extract_address_from_text(text)
    
    return {
        "category": category,
        "address": address,
        "summary": text[:100] if len(text) > 100 else text,
        "relevant": True,
        "provider": "keyword"
    }


async def claude_geoparse(text: str) -> Tuple[float, float, str]:
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
            "summary": text[:100]
        }
    
    # 2. Извлекаем адрес
    address = ai_result.get('address')
    if not address:
        address = _extract_address_from_text(text)
    
    # 3. Если адреса нет - используем категорию для поиска
    if not address:
        category = ai_result.get('category', 'Прочее')
        if category != 'Прочее':
            address = category
        else:
            address = DEFAULT_ADDRESS
    
    # 4. Геокодинг
    lat, lng = await nominatim_geocode(address)
    
    logger.info(f"Geoparse result: {address} -> [{lat}, {lng}]")
    
    return lat, lng, address


async def parse_complaint_with_ai(text: str) -> Dict[str, Any]:
    """Полный анализ жалобы с AI и геокодингом"""
    # AI анализ
    ai_result = await analyze_with_ai(text)
    
    # Извлекаем адрес
    address = ai_result.get('address')
    if not address:
        address = _extract_address_from_text(text)
    
    # Геокодинг
    lat, lng = await nominatim_geocode(address if address else ai_result.get('category', 'Прочее'))
    
    return {
        "category": ai_result.get('category', 'Прочее'),
        "lat": lat,
        "lng": lng,
        "address": address or DEFAULT_ADDRESS,
        "summary": ai_result.get('summary', text[:100]),
        "relevant": ai_result.get('relevant', True),
        "provider": ai_result.get('provider', 'unknown')
    }
