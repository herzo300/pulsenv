# services/zai_service.py
"""
AI complaint analysis: Z.AI (primary) / OpenRouter (fallback) / keyword (last resort).

Provides text classification for city complaints with category, address,
severity, and relevance detection.
"""

import json
import logging
import os
import re
from typing import Any, Dict, List, Optional

from core.http_client import get_http_client, get_proxy_url
from services.ai_cache import get_cached_text, set_cached_text

logger = logging.getLogger(__name__)

# Canonical list of complaint categories (single source of truth)
CATEGORIES: list[str] = [
    "ЖКХ", "Дороги", "Благоустройство", "Транспорт", "Экология",
    "Животные", "Торговля", "Безопасность", "Снег/Наледь", "Освещение",
    "Медицина", "Образование", "Связь", "Строительство", "Парковки",
    "Социальная сфера", "Трудовое право", "Прочее", "ЧП",
    "Газоснабжение", "Водоснабжение и канализация", "Отопление",
    "Бытовой мусор", "Лифты и подъезды", "Парки и скверы",
    "Спортивные площадки", "Детские площадки",
]

# --- AI provider configuration ---
XAI_API_KEY: str = os.getenv("XAI_API_KEY", "").strip()
XAI_BASE: str = os.getenv("XAI_BASE_URL", "https://api.x.ai/v1")
XAI_TEXT_MODEL: str = os.getenv("XAI_TEXT_MODEL", "grok-2-latest")

# Log provider status at import
if XAI_API_KEY:
    logger.info("Grok initialized (model: %s)", XAI_TEXT_MODEL)
else:
    logger.warning("XAI_API_KEY not set — will fallback to keyword")

AI_TEXT_PROVIDER: str = os.getenv("AI_TEXT_PROVIDER", "grok").strip().lower()
if AI_TEXT_PROVIDER not in ("grok", "keyword"):
    AI_TEXT_PROVIDER = "grok"

# --- System prompt and user prompt ---
SYSTEM_PROMPT: str = (
    "Ты — строгий фильтр и аналитик городских проблем Нижневартовска (ХМАО, Россия). "
    "Твоя задача: определить, является ли сообщение РЕАЛЬНОЙ городской проблемой/жалобой, "
    "и если да — извлечь категорию, кратко описать суть проблемы для базы данных и оценить её серьёзность.\n\n"
    "ПРАВИЛА ФИЛЬТРАЦИИ (СТРОГО):\n"
    "1. ОТКЛОНЯЙ (relevant=false): рекламу, продажи, вакансии, розыгрыши, гороскопы, "
    "мемы, шутки, анекдоты, поздравления, опросы, голосования, новости без проблемы, "
    "политику без городской проблемы, развлечения, афиши, погоду (без ЧП), "
    "объявления о пропаже животных/вещей, просьбы о помощи не связанные с городом.\n"
    "2. ПРИНИМАЙ (relevant=true): жалобы на ЖКХ, дороги, транспорт, освещение, мусор, "
    "аварии, ЧП, пожары, затопления, поломки, опасные ситуации, проблемы благоустройства.\n"
    "3. АДРЕС: извлеки точный адрес из текста (улица, дом). Если адреса нет — null.\n"
    "4. Город ТОЛЬКО Нижневартовск. Если речь о другом городе — relevant=false.\n"
    "5. СЕРЬЁЗНОСТЬ (severity): оцени жалобу по трёхбалльной шкале:\n"
    "   1 — низкая (косметические, неопасные неудобства),\n"
    "   2 — средняя (затяжные проблемы, но без прямой угрозы жизни),\n"
    "   3 — высокая (ЧП, аварии, угрозы безопасности, риск для жизни и здоровья).\n"
    "6. При severity=3 приоритет (priority) всегда 'высокий'.\n\n"
    "Отвечай ТОЛЬКО валидным JSON без markdown."
)


def _make_prompt(text: str) -> str:
    """Build the user prompt for AI analysis."""
    return (
        f"Проанализируй сообщение из паблика Нижневартовска.\n\n"
        f"Категории проблем: {', '.join(CATEGORIES)}\n\n"
        f"Текст сообщения:\n\"\"\"\n{text[:1500]}\n\"\"\"\n\n"
        f"Определи:\n"
        f"1. relevant — это реальная городская проблема/жалоба? (true/false)\n"
        f"2. category — категория из списка (если relevant=true)\n"
        f"3. address — точный адрес. Варианты формата:\n"
        f"   - Дом: 'ул. Мира 62' или 'пр. Победы 12а'\n"
        f"   - Перекрёсток: 'перекрёсток ул. Мира и ул. Ленина'\n"
        f"   - Район: 'мкр. 10П д. 5'\n"
        f"   Если адреса нет — null\n"
        f"4. summary — КРАТКАЯ СВОДКА для базы данных/служебного канала. "
        f"СТРОГО запрещено копировать текст поста! "
        f"Сформулируй суть жалобы своими словами: что случилось, где, основные последствия. "
        f"Максимум 1–2 коротких предложения, до 120 символов. Пиши сухим деловым стилем.\n"
        f"5. severity — оценка серьёзности жалобы (целое число 1, 2 или 3).\n"
        f"6. priority — текстовый приоритет: 'низкий', 'средний' или 'высокий'.\n"
        f"7. location_hints — любые подсказки о месте (район, ориентир, ТЦ/школа/больница). "
        f"Если нет — null\n\n"
        f'Верни JSON: {{"relevant":true/false,"category":"...","address":"...или null",'
        f'"summary":"...","severity":1/2/3,"priority":"низкий/средний/высокий",'
        f'"location_hints":"...или null"}}'
    )


def _parse_json(text: str) -> Optional[Dict[str, Any]]:
    """Extract JSON from model response (may be wrapped in ```json)."""
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r"\{[^{}]*\}", text, re.DOTALL)
        if m:
            try:
                return json.loads(m.group())
            except json.JSONDecodeError:
                pass
    return None


# --- Shared retry-with-proxy logic ---
async def _call_ai_api(
    api_url: str,
    payload: dict,
    headers: dict,
    label: str,
) -> Optional[str]:
    """
    Call an AI chat/completions endpoint with proxy fallback.

    Returns the content string from the first successful response, or None.
    """
    proxy_url = get_proxy_url()
    attempts = [(False, "direct"), (True, "proxy")]

    for use_proxy, mode in attempts:
        if use_proxy and not proxy_url:
            continue
        try:
            px = proxy_url if use_proxy else None
            async with get_http_client(timeout=60.0, proxy=px) as client:
                r = await client.post(api_url, json=payload, headers=headers)

            if r.status_code != 200:
                logger.warning("%s [%s] HTTP %d: %s", label, mode, r.status_code, r.text[:200])
                continue

            data = r.json()
            msg = data.get("choices", [{}])[0].get("message", {})
            content = msg.get("content") or msg.get("reasoning_content") or ""
            if content:
                return content
        except Exception as e:
            logger.debug("%s [%s] error: %s", label, mode, e)

    return None


async def _grok_analyze(text: str) -> Optional[Dict[str, Any]]:
    """Analyze via Grok (xAI) with caching."""
    if not XAI_API_KEY:
        return None

    cached = get_cached_text(text, XAI_TEXT_MODEL)
    if cached:
        return cached

    payload = {
        "model": XAI_TEXT_MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": _make_prompt(text)},
        ],
        "temperature": 0.1,
    }
    headers = {
        "Authorization": f"Bearer {XAI_API_KEY}",
        "Content-Type": "application/json",
    }

    content = await _call_ai_api(
        f"{XAI_BASE}/chat/completions", payload, headers, "Grok"
    )
    if not content:
        logger.error("Grok: all attempts failed")
        return None

    result = _parse_json(content)
    if result:
        logger.info("Grok (%s): category=%s", XAI_TEXT_MODEL, result.get("category"))
        set_cached_text(text, result, XAI_TEXT_MODEL)
    return result





# --- Keyword rules for severity assignment ---
_HIGH_RISK_CATS = frozenset({
    "ЧП", "Безопасность", "Газоснабжение", "Водоснабжение и канализация", "Отопление",
})
_MEDIUM_RISK_CATS = frozenset({
    "Дороги", "Снег/Наледь", "Освещение", "Бытовой мусор",
    "Лифты и подъезды", "Парки и скверы", "Детские площадки",
})


def _keyword_analyze(text: str) -> Dict[str, Any]:
    """Keyword-based fallback analysis (no AI)."""
    t = text.lower()

    keyword_rules = [
        ("Освещение", ["фонар", "освещен", "свет не гор", "темно", "лампа"]),
        ("Дороги", ["яма", "дорог", "асфальт", "тротуар", "выбоин", "колея"]),
        ("Снег/Наледь", ["снег", "налед", "гололёд", "гололед", "сугроб", "не чищ"]),
        ("ЖКХ", ["жкх", "управляющ", "коммунал", "квитанц", "тариф"]),
        ("Отопление", ["отоплен", "батаре", "холодн", "не греет"]),
        ("Водоснабжение и канализация", ["канализ", "труб", "течь", "затоп", "прорыв"]),
        ("Бытовой мусор", ["мусор", "свалк", "отход", "контейнер"]),
        ("Транспорт", ["автобус", "маршрут", "транспорт", "остановк"]),
        ("Благоустройство", ["двор", "клумб", "газон", "лавочк", "скамейк"]),
        ("Экология", ["эколог", "загрязн", "выброс", "запах"]),
        ("Парковки", ["парков", "стоянк"]),
        ("Лифты и подъезды", ["лифт", "подъезд", "домофон"]),
        ("Детские площадки", ["детск", "площадк", "качел", "горк"]),
        ("Безопасность", ["безопасн", "полиц", "кража", "вандал"]),
        ("Медицина", ["больниц", "поликлиник", "врач", "скорая"]),
        ("Газоснабжение", ["газ ", "газов", "газоснабж"]),
        ("Строительство", ["строй", "стройк"]),
        ("ЧП", ["пожар", "взрыв", "авари", "обрушен"]),
    ]

    category = "Прочее"
    for cat, keywords in keyword_rules:
        if any(kw in t for kw in keywords):
            category = cat
            break

    # Address extraction via regex
    address = None
    for pat in [
        r'(?:ул(?:ица|ице)?\.?\s+)([А-Яа-яЁё]+(?:\s+[А-Яа-яЁё]+)?)\s*,?\s*(\d+[а-яА-Я]?)',
        r'(?:пр(?:оспект|оспекте)?\.?\s+)([А-Яа-яЁё]+(?:\s+[А-Яа-яЁё]+)?)\s*,?\s*(\d+[а-яА-Я]?)',
    ]:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            address = f"ул. {m.group(1)} {m.group(2)}, Нижневартовск"
            break

    # Severity based on category
    if category in _HIGH_RISK_CATS:
        severity, priority = 3, "высокий"
    elif category in _MEDIUM_RISK_CATS:
        severity, priority = 2, "средний"
    else:
        severity, priority = 1, "низкий"

    summary = f"Проблема ({category}, приор. {priority}): требуется проверка и разбор ситуации."

    return {
        "category": category,
        "address": address,
        "summary": summary[:120],
        "relevant": category != "Прочее",
        "location_hints": None,
        "severity": severity,
        "priority": priority,
        "method": "keyword",
    }


# --- Public API ---


def get_ai_provider() -> str:
    """Current active text analysis provider."""
    return AI_TEXT_PROVIDER


def set_ai_provider(provider: str) -> bool:
    """Switch active provider at runtime (no restart required)."""
    global AI_TEXT_PROVIDER
    p = (provider or "").strip().lower()
    if p not in ("grok", "keyword"):
        return False
    AI_TEXT_PROVIDER = p
    logger.info("AI text provider switched to: %s", AI_TEXT_PROVIDER)
    return True


def get_ai_provider_status() -> Dict[str, Any]:
    """Provider status for admin panel."""
    return {
        "active": AI_TEXT_PROVIDER,
        "xai_configured": bool(XAI_API_KEY),
        "xai_model": XAI_TEXT_MODEL,
    }


async def analyze_complaint(text: str) -> Dict[str, Any]:
    """
    Analyze a complaint using the configured provider chain with fallback.

    Returns dict: relevant, category, address, summary, severity, priority,
    location_hints, provider.
    """
    order: List[str]
    if AI_TEXT_PROVIDER == "grok":
        order = ["grok", "keyword"]
    else:
        order = ["keyword"]

    for provider in order:
        if provider == "grok":
            result = await _grok_analyze(text)
            if result:
                result["provider"] = f"grok:{XAI_TEXT_MODEL}"
                return _normalize_result(result)
        elif provider == "keyword":
            break

    logger.warning("AI providers unavailable, using keyword analysis")
    result = _keyword_analyze(text)
    result["provider"] = "keyword"
    return result


def _normalize_result(result: Dict[str, Any]) -> Dict[str, Any]:
    """Normalize AI result: clean address, validate relevant field."""
    # Default relevant to True for backward compatibility
    if "relevant" not in result:
        result["relevant"] = True

    # Coerce to bool
    rel = result["relevant"]
    if isinstance(rel, str):
        result["relevant"] = rel.lower() in ("true", "1", "yes", "да")

    # Clean address duplicates like "ул. улице Мира"
    addr = result.get("address")
    if addr and isinstance(addr, str):
        addr = re.sub(r"ул\.\s*улиц[еы]\s+", "ул. ", addr)
        addr = re.sub(r"пр\.\s*проспект[еа]\s+", "пр. ", addr)
        addr = addr.strip().rstrip(",")
        if addr.lower() in ("null", "нет", "-", "не указан", "не указано", ""):
            addr = None
        result["address"] = addr

    # Clean location_hints
    if result.get("location_hints") in (None, "null", "нет", "-", ""):
        result["location_hints"] = None

    return result


# --- Convenience wrappers ---


async def analyze_complaint_with_llm(
    text: str, category_filter: List[str] = None
) -> Dict[str, Any]:
    """Alias for analyze_complaint (backward compatibility)."""
    return await analyze_complaint(text)


def extract_categories_from_text(text: str) -> List[str]:
    """Extract matching categories from text."""
    return [c for c in CATEGORIES if c in text]


class AIAnalyzer:
    """Convenience wrapper class for AI analysis."""

    @staticmethod
    async def analyze(text: str) -> Dict[str, Any]:
        return await analyze_complaint(text)

    @staticmethod
    async def categorize(text: str) -> str:
        return (await analyze_complaint(text)).get("category", "Прочее")

    @staticmethod
    async def extract_address(text: str) -> Optional[str]:
        return (await analyze_complaint(text)).get("address")


def get_ai_service():
    """Get an AIAnalyzer instance."""
    return AIAnalyzer()
