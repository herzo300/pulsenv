# services/zai_service.py
# AI анализ жалоб: только OpenRouter (qwen 3.5 coder для текста) → keyword fallback
import os
import re
import json
import logging
from typing import Any, Dict, List
import httpx
from core.http_client import get_http_client, get_proxy_url
from services.ai_cache import get_cached_text, set_cached_text

logger = logging.getLogger(__name__)

CATEGORIES = [
    "ЖКХ", "Дороги", "Благоустройство", "Транспорт", "Экология",
    "Животные", "Торговля", "Безопасность", "Снег/Наледь", "Освещение",
    "Медицина", "Образование", "Связь", "Строительство", "Парковки",
    "Социальная сфера", "Трудовое право", "Прочее", "ЧП",
    "Газоснабжение", "Водоснабжение и канализация", "Отопление",
    "Бытовой мусор", "Лифты и подъезды", "Парки и скверы",
    "Спортивные площадки", "Детские площадки",
]

# --- OpenRouter (единственный AI провайдер) ---
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
OPENROUTER_BASE = "https://openrouter.ai/api/v1"
# qwen 3.5 coder для анализа текста из пабликов
OPENROUTER_TEXT_MODEL = os.getenv("OPENROUTER_TEXT_MODEL", "qwen/qwen3-coder")

if OPENROUTER_API_KEY:
    print(f"[OK] OpenRouter initialized (text model: {OPENROUTER_TEXT_MODEL})")
else:
    print("[WARN] OPENROUTER_API_KEY не задан — будет использоваться keyword fallback")


SYSTEM_PROMPT = (
    "Ты — строгий фильтр и аналитик городских проблем Нижневартовска (ХМАО, Россия). "
    "Твоя задача: определить, является ли сообщение РЕАЛЬНОЙ городской проблемой/жалобой, "
    "и если да — извлечь категорию, точный адрес и координаты.\n\n"
    "ПРАВИЛА ФИЛЬТРАЦИИ (СТРОГО):\n"
    "1. ОТКЛОНЯЙ (relevant=false): рекламу, продажи, вакансии, розыгрыши, гороскопы, "
    "мемы, шутки, анекдоты, поздравления, опросы, голосования, новости без проблемы, "
    "политику без городской проблемы, развлечения, афиши, погоду (без ЧП), "
    "объявления о пропаже животных/вещей, просьбы о помощи не связанные с городом.\n"
    "2. ПРИНИМАЙ (relevant=true): жалобы на ЖКХ, дороги, транспорт, освещение, мусор, "
    "аварии, ЧП, пожары, затопления, поломки, опасные ситуации, проблемы благоустройства.\n"
    "3. АДРЕС: извлеки точный адрес из текста (улица, дом). Если адреса нет — null.\n"
    "4. Город ТОЛЬКО Нижневартовск. Если речь о другом городе — relevant=false.\n\n"
    "Отвечай ТОЛЬКО валидным JSON без markdown."
)

def _make_prompt(text: str) -> str:
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
        f"4. summary — КРАТКАЯ СВОДКА для служебного канала. СТРОГО запрещено копировать текст поста! "
        f"Сформулируй суть проблемы своими словами: что случилось, где, последствия. "
        f"Максимум 1–2 коротких предложения, до 120 символов. Пиши как аналитик.\n"
        f"5. location_hints — любые подсказки о месте: район, ориентир, "
        f"название ТЦ/школы/больницы (если есть). Если нет — null\n\n"
        f'Верни JSON: {{"relevant":true/false,"category":"...","address":"...или null",'
        f'"summary":"...","location_hints":"...или null"}}'
    )


def _parse_json(text: str) -> Dict[str, Any] | None:
    """Извлечь JSON из ответа модели (может быть обёрнут в ```json)"""
    text = text.strip()
    # Убираем markdown code block
    if text.startswith("```"):
        text = re.sub(r'^```(?:json)?\s*', '', text)
        text = re.sub(r'\s*```$', '', text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r'\{[^{}]*\}', text, re.DOTALL)
        if m:
            try:
                return json.loads(m.group())
            except json.JSONDecodeError:
                pass
    return None


async def _openrouter_analyze(text: str) -> Dict[str, Any] | None:
    """Анализ через OpenRouter (qwen 3.5 coder для текста) с кэшированием"""
    if not OPENROUTER_API_KEY:
        return None
    
    # Проверяем кэш
    cached = get_cached_text(text, OPENROUTER_TEXT_MODEL)
    if cached:
        logger.debug(f"✅ Using cached result for text analysis")
        return cached
    
    # Пробуем без прокси, затем с прокси (fallback при блокировке)
    proxy_url = get_proxy_url()
    payload = {
        "model": OPENROUTER_TEXT_MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": _make_prompt(text)},
        ],
        "max_tokens": 2048,
    }
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/soobshio/soobshio",
        "X-Title": "Soobshio Complaint Analyzer",
    }
    for use_proxy, label in [(False, "без прокси"), (True, "с прокси")]:
        if use_proxy and not proxy_url:
            continue
        try:
            async with get_http_client(timeout=60.0, proxy=proxy_url if use_proxy else None) as client:
                r = await client.post(f"{OPENROUTER_BASE}/chat/completions", json=payload, headers=headers)
            if r.status_code != 200:
                logger.error(f"OpenRouter [{label}] {r.status_code} {r.text[:100]}")
                continue
            d = r.json()
            msg = d.get("choices", [{}])[0].get("message", {})
            content = msg.get("content", "")
            if not content:
                continue
            result = _parse_json(content)
            if result:
                logger.info(f"✅ OpenRouter [{label}] ({OPENROUTER_TEXT_MODEL}): {result.get('category')}")
                set_cached_text(text, result, OPENROUTER_TEXT_MODEL)
                return result
        except Exception as e:
            logger.debug(f"OpenRouter [{label}] error: {e}")
    logger.error("OpenRouter: все попытки не удались")
    return None


def _keyword_analyze(text: str) -> Dict[str, Any]:
    """Keyword-based анализ (fallback без AI)"""
    t = text.lower()
    rules = [
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
    for cat, kws in rules:
        if any(kw in t for kw in kws):
            category = cat
            break
    # Адрес
    address = None
    for pat in [
        r'(?:ул(?:ица|ице)?\.?\s+)([А-Яа-яЁё]+(?:\s+[А-Яа-яЁё]+)?)\s*,?\s*(\d+[а-яА-Я]?)',
        r'(?:пр(?:оспект|оспекте)?\.?\s+)([А-Яа-яЁё]+(?:\s+[А-Яа-яЁё]+)?)\s*,?\s*(\d+[а-яА-Я]?)',
    ]:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            address = f"ул. {m.group(1)} {m.group(2)}, Нижневартовск"
            break
    # Fallback: краткая сводка, не копируем пост
    short = f"Проблема: {category}" + (f", {text[:40]}..." if len(text) > 40 else "")
    return {"category": category, "address": address, "summary": short[:120], "relevant": category != "Прочее", "location_hints": None, "method": "keyword"}


async def analyze_complaint(text: str) -> Dict[str, Any]:
    """
    Анализ жалобы: OpenRouter (qwen 3.5 coder) → keyword fallback.
    Возвращает dict с полями: relevant, category, address, summary, location_hints, provider.
    """
    # 1. OpenRouter (qwen 3.5 coder)
    result = await _openrouter_analyze(text)
    if result:
        result["provider"] = f"openrouter:{OPENROUTER_TEXT_MODEL}"
        return _normalize_result(result)

    # 2. Keyword fallback
    logger.warning("⚠️ OpenRouter недоступен, keyword-анализ")
    result = _keyword_analyze(text)
    result["provider"] = "keyword"
    return result


def _normalize_result(result: Dict[str, Any]) -> Dict[str, Any]:
    """Нормализует результат AI: чистит адрес, проверяет relevant."""
    # relevant по умолчанию true (для обратной совместимости)
    if "relevant" not in result:
        result["relevant"] = True
    # Приводим к bool
    rel = result["relevant"]
    if isinstance(rel, str):
        result["relevant"] = rel.lower() in ("true", "1", "yes", "да")

    # Чистим адрес от дублей типа "ул. улице Мира"
    addr = result.get("address")
    if addr and isinstance(addr, str):
        addr = re.sub(r'ул\.\s*улиц[еы]\s+', 'ул. ', addr)
        addr = re.sub(r'пр\.\s*проспект[еа]\s+', 'пр. ', addr)
        addr = addr.strip().rstrip(',')
        if addr.lower() in ('null', 'нет', '-', 'не указан', 'не указано', ''):
            addr = None
        result["address"] = addr

    # location_hints
    if result.get("location_hints") in (None, "null", "нет", "-", ""):
        result["location_hints"] = None

    return result


async def analyze_complaint_with_llm(text: str, category_filter: List[str] = None) -> Dict[str, Any]:
    return await analyze_complaint(text)


def extract_categories_from_text(text: str) -> List[str]:
    return [c for c in CATEGORIES if c in text]


class AIAnalyzer:
    @staticmethod
    async def analyze(text: str) -> Dict[str, Any]:
        return await analyze_complaint(text)

    @staticmethod
    async def categorize(text: str) -> str:
        return (await analyze_complaint(text)).get("category", "Прочее")

    @staticmethod
    async def extract_address(text: str) -> str | None:
        return (await analyze_complaint(text)).get("address")


def get_ai_service():
    return AIAnalyzer()
