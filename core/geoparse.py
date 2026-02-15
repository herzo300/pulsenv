import os
import json
import re
import httpx
from core.http_client import get_http_client
from typing import Tuple, Optional, Dict, Any
from dotenv import load_dotenv
from services.zai_service import analyze_complaint

load_dotenv()
API_KEY = os.getenv('ZAI_API_KEY')


async def claude_geoparse(text: str) -> Tuple[float, float, str]:
    """
    Zai GLM-4.7 + Nominatim → address + coordinates for Nizhnevartovsk
    Zai анализирует текст, Nominatim геокодит.
    """
    prompt = f"""
Текст жалобы: "{text}"

1. Найди категорию
2. Если адреса нет → "Нижневартовск центр"
3. Верни ТОЛЬКО JSON:
{{"category": "ул Ленина 15", "summary": "краткое описание"}}

Пример: "Яма на Ленина 15" → {{"category": "ул Ленина 15", "summary": "яма"}}
"""

    if not API_KEY:
        return 61.034, 76.553, "Нижневартовск центр"

    # Используем Zai для анализа текста
    try:
        ai_result = await analyze_complaint(text)
        category = ai_result.get('category', 'Нижневартовск центр')
        summary = ai_result.get('summary', text[:100])

        # Nominatim для координат
        lat, lng = await nominatim_geocode(category)
        return lat, lng, category

    except Exception as e:
        print(f"Zai geoparse error: {e}")

    return 61.034, 76.553, "Нижневартовск центр"


async def nominatim_geocode(address: str) -> Tuple[float, float]:
    """Nominatim для геокодинга адреса"""
    url = "https://nominatim.openstreetmap.org/search"
    params = {
        'q': f"Нижневартовск {address}",
        'format': 'json',
        'limit': 1
    }
    headers = {'User-Agent': 'Soobshio/1.0'}

    try:
        async with get_http_client(timeout=10.0) as client:
            resp = await client.get(url, params=params, headers=headers, timeout=5.0)
            data = resp.json()
            if data:
                return float(data[0]['lat']), float(data[0]['lon'])
    except Exception:
        pass

    return 61.034, 76.553


async def parse_complaint_with_ai(text: str) -> Dict[str, Any]:
    """
    Полный анализ жалобы через Zai и Nominatim.
    """
    # Анализ через Zai
    ai_result = await analyze_complaint(text)
    category = ai_result.get('category', 'Прочее')
    summary = ai_result.get('summary', text[:100])

    # Геокодинг через Nominatim
    lat, lng = await nominatim_geocode(category)

    return {
        "category": category,
        "lat": lat,
        "lng": lng,
        "summary": summary
    }
