# services/zai_service.py
# AI анализ жалоб: Z.AI (основной) → Anthropic → OpenAI → keyword fallback
import os
import re
import json
import logging
from typing import Any, Dict, List
import httpx
from core.http_client import get_http_client

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

# --- Z.AI (основной, бесплатный) ---
ZAI_API_KEY = os.getenv("ZAI_API_KEY", "")
ZAI_BASE = "https://api.z.ai/api/paas/v4"
ZAI_TEXT_MODEL = "glm-4.7-flash"  # основная модель текстового анализа
ZAI_VISION_MODEL = "GLM-4.7V"  # vision-модель

if ZAI_API_KEY:
    print(f"✅ Z.AI initialized (text: {ZAI_TEXT_MODEL}, vision: {ZAI_VISION_MODEL})")

# --- Anthropic (fallback 1) ---
_anthropic_client = None
_anthropic_key = os.getenv("ANTHROPIC_API_KEY", "")
_anthropic_base_url = os.getenv("ANTHROPIC_BASE_URL", "")
try:
    if _anthropic_key:
        from anthropic import Anthropic
        kwargs = {"api_key": _anthropic_key}
        if _anthropic_base_url:
            kwargs["base_url"] = _anthropic_base_url
        _anthropic_client = Anthropic(**kwargs)
        proxy_info = f" (proxy: {_anthropic_base_url})" if _anthropic_base_url else ""
        print(f"✅ Anthropic client initialized{proxy_info}")
except Exception as e:
    print(f"Anthropic client error: {e}")

# --- OpenAI (fallback 2) ---
_openai_client = None
_openai_key = os.getenv("OPENAI_API_KEY", "")
try:
    if _openai_key:
        from openai import AsyncOpenAI
        kwargs = {"api_key": _openai_key}
        _openai_base_url = os.getenv("OPENAI_BASE_URL", "")
        if _openai_base_url:
            kwargs["base_url"] = _openai_base_url
        _openai_client = AsyncOpenAI(**kwargs)
        proxy_info = f" (proxy: {_openai_base_url})" if _openai_base_url else ""
        print(f"✅ OpenAI client initialized{proxy_info}")
except Exception as e:
    print(f"OpenAI client error: {e}")


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
        f"4. summary — НЕ КОПИРУЙ текст. Напиши свой краткий анализ проблемы: "
        f"что случилось, в чём суть, какие последствия. Максимум 2 предложения, до 150 символов. "
        f"Пиши как аналитик, а не как копирайтер.\n"
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


async def _zai_analyze(text: str) -> Dict[str, Any] | None:
    """Анализ через Z.AI (glm-4.7-flash)"""
    if not ZAI_API_KEY:
        return None
    try:
        async with get_http_client(timeout=60.0) as client:
            r = await client.post(
                f"{ZAI_BASE}/chat/completions",
                json={
                    "model": ZAI_TEXT_MODEL,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": _make_prompt(text)},
                    ],
                    "max_tokens": 4096,
                },
                headers={
                    "Authorization": f"Bearer {ZAI_API_KEY}",
                    "Content-Type": "application/json",
                },
            )
        if r.status_code != 200:
            logger.error(f"Z.AI error: {r.status_code} {r.text[:200]}")
            return None
        d = r.json()
        msg = d["choices"][0]["message"]
        content = msg.get("content", "")
        # glm-4.7-flash reasoning: JSON может быть в reasoning_content
        if not content:
            reasoning = msg.get("reasoning_content", "")
            if reasoning:
                result = _parse_json(reasoning)
                if result:
                    logger.info(f"✅ Z.AI анализ (reasoning): {result.get('category')}")
                    return result
            logger.warning("Z.AI: empty content")
            return None
        result = _parse_json(content)
        if result:
            logger.info(f"✅ Z.AI анализ: {result.get('category')}")
            return result
        logger.warning(f"Z.AI: failed to parse JSON from: {content[:200]}")
    except Exception as e:
        logger.error(f"Z.AI error: {e}")
    return None


def _anthropic_analyze(text: str) -> Dict[str, Any] | None:
    """Анализ через Anthropic Claude (sync)"""
    if not _anthropic_client:
        return None
    try:
        response = _anthropic_client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=300,
            messages=[{"role": "user", "content": _make_prompt(text)}],
        )
        content = response.content[0].text.strip()
        result = _parse_json(content)
        if result:
            logger.info(f"✅ Anthropic анализ: {result.get('category')}")
            return result
    except Exception as e:
        logger.error(f"Anthropic error: {e}")
    return None


async def _openai_analyze(text: str) -> Dict[str, Any] | None:
    """Анализ через OpenAI (async)"""
    if not _openai_client:
        return None
    try:
        response = await _openai_client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": _make_prompt(text)},
            ],
            max_tokens=300,
        )
        content = response.choices[0].message.content.strip()
        result = _parse_json(content)
        if result:
            logger.info(f"✅ OpenAI анализ: {result.get('category')}")
            return result
    except Exception as e:
        logger.error(f"OpenAI error: {e}")
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
    return {"category": category, "address": address, "summary": f"Проблема ({category.lower()}): {text[:80]}", "relevant": category != "Прочее", "location_hints": None, "method": "keyword"}


async def analyze_complaint(text: str) -> Dict[str, Any]:
    """
    Анализ жалобы: Z.AI → Anthropic → OpenAI → keyword fallback.
    Возвращает dict с полями: relevant, category, address, summary, location_hints, provider.
    """
    # 1. Z.AI (бесплатный, основной)
    result = await _zai_analyze(text)
    if result:
        result["provider"] = "z.ai"
        return _normalize_result(result)

    # 2. Anthropic (через прокси)
    result = _anthropic_analyze(text)
    if result:
        result["provider"] = "anthropic"
        return _normalize_result(result)

    # 3. OpenAI (через прокси)
    result = await _openai_analyze(text)
    if result:
        result["provider"] = "openai"
        return _normalize_result(result)

    # 4. Keyword fallback
    logger.warning("⚠️ AI недоступен, keyword-анализ")
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
