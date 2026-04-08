# services/zai_service.py
"""
AI complaint analysis: Z.AI (primary) / LiteLLM / Ollama / keyword (last resort).

Provides text classification for city complaints with category, address,
severity, and relevance detection.
"""

import json
import logging
import os
import re
import time
from typing import Any, Dict, List, Optional

from core.http_client import get_http_client, get_proxy_url
from services.ai_cache import get_cached_text, set_cached_text

logger = logging.getLogger(__name__)


def _normalize_api_key(value: str) -> str:
    token = str(value or "").strip()
    if token.lower().startswith("z.ai "):
        token = token.split(" ", 1)[1].strip()
    return token

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
ZAI_API_KEY: str = _normalize_api_key(os.getenv("ZAI_API_KEY", ""))
ZAI_BASE: str = os.getenv("ZAI_BASE_URL", "https://open.bigmodel.cn/api/paas/v4").strip().rstrip("/")
ZAI_TEXT_MODEL: str = os.getenv("ZAI_TEXT_MODEL", "glm-5-turbo").strip() or "glm-5-turbo"
ZAI_REQUEST_TIMEOUT: float = float(os.getenv("ZAI_REQUEST_TIMEOUT", "90"))

if ZAI_API_KEY:
    logger.info("ZAI configured (model: %s)", ZAI_TEXT_MODEL)

LITELLM_URL: str = os.getenv("LITELLM_URL", "http://litellm:4000").strip().rstrip("/")
LITELLM_TEXT_MODEL: str = os.getenv("LITELLM_TEXT_MODEL", "gemma4-text").strip() or "gemma4-text"
LITELLM_MASTER_KEY: str = os.getenv("LITELLM_MASTER_KEY", "").strip()
LITELLM_REQUEST_TIMEOUT: float = float(os.getenv("LITELLM_REQUEST_TIMEOUT", "180"))
LITELLM_URLS: list[str] = []
for candidate in (
    LITELLM_URL,
    "http://litellm:4000",
    "http://127.0.0.1:4000",
    "http://localhost:4000",
):
    normalized = str(candidate or "").strip().rstrip("/")
    if normalized and normalized not in LITELLM_URLS:
        LITELLM_URLS.append(normalized)

OLLAMA_URL: str = os.getenv("OLLAMA_URL", "http://ollama:11434").strip().rstrip("/")
OLLAMA_TEXT_MODEL: str = os.getenv("OLLAMA_TEXT_MODEL", "gemma4:4b").strip() or "gemma4:4b"
OLLAMA_REQUEST_TIMEOUT: float = float(os.getenv("OLLAMA_REQUEST_TIMEOUT", "180"))
OLLAMA_URLS: list[str] = []
for candidate in (
    OLLAMA_URL,
    "http://ollama:11434",
    "http://127.0.0.1:11434",
    "http://localhost:11434",
):
    normalized = str(candidate or "").strip().rstrip("/")
    if normalized and normalized not in OLLAMA_URLS:
        OLLAMA_URLS.append(normalized)

AI_TEXT_PROVIDER: str = os.getenv("AI_TEXT_PROVIDER", "litellm").strip().lower()
if AI_TEXT_PROVIDER not in ("zai", "litellm", "ollama", "keyword"):
    AI_TEXT_PROVIDER = "litellm"

# --- System prompt and user prompt ---
SYSTEM_PROMPT: str = (
    "Ты — глубокий аналитик городских проблем Нижневартовска. "
    "Твоя задача: анализировать входящие сообщения и определять, являются ли они РЕАЛЬНОЙ городской проблемой.\n\n"
    "ПРАВИЛА (СТРОГО):\n"
    "1. ТЕРМИНОЛОГИЯ: Используй термин 'городская проблема' вместо 'жалоба'.\n"
    "2. ОТКЛОНЯЙ (relevant=false): рекламу, продажи, вакансии, розыгрыши, мемы, "
    "шутки, анекдоты, поздравления, опросы, новости без конкретной проблемы, "
    "политику без городской проблемы, объявления о пропаже животных/вещей.\n"
    "3. ПРИНИМАЙ (relevant=true): проблемы ЖКХ, дорог, транспорта, освещения, мусора, "
    "аварии, ЧП, поломки, опасные ситуации, проблемы благоустройства.\n"
    "4. АДРЕС: извлекай точный адрес (улица, дом). Если не уверен на 100% — пиши null.\n"
    "5. СЕРЬЁЗНОСТЬ (severity): оценивай по шкале 1-3.\n"
    "6. ГЛУБОКИЙ АНАЛИЗ: Не используй типовые фразы. Описывай ситуацию своими словами, "
    "вникая в детали и последствия.\n\n"
    "Отвечай ТОЛЬКО валидным JSON без markdown."
)


def _make_prompt(text: str) -> str:
    """Build the user prompt for AI analysis."""
    return (
        f"Проанализируй сообщение о городской ситуации в Нижневартовске.\n\n"
        f"Категории: {', '.join(CATEGORIES)}\n\n"
        f"Текст сообщения:\n\"\"\"\n{text[:1500]}\n\"\"\"\n\n"
        f"Определи:\n"
        f"1. relevant — это реальная городская проблема? (true/false)\n"
        f"2. category — категория из списка (если relevant=true)\n"
        f"3. address — точный адрес. Если не уверен на 100% — null.\n"
        f"4. summary — ГЛУБОКОЕ ОПИСАНИЕ СВОИМИ СЛОВАМИ. Запрещено использовать клише "
        f"вроде 'требуется проверка'. Опиши суть ситуации, её детали и возможные "
        f"последствия так, чтобы это было интересно и понятно жителям в ТГ-канале. "
        f"Максимум 3-4 содержательных предложения.\n"
        f"5. severity — оценка серьёзности (1, 2 или 3).\n"
        f"6. priority — 'низкий', 'средний' или 'высокий'.\n"
        f"7. location_hints — ориентиры, если адрес неточный.\n\n"
        f'Верни JSON: {{"relevant":true/false,"category":"...","address":"...или null",'
        f'"summary":"...","severity":1/2/3,"priority":"...","location_hints":"..."}}'
    )


def _make_ollama_prompt(text: str) -> str:
    """Compact prompt for local Ollama models (Gemma 4 / qwen).

    Gemma 4 supports native system prompts, but we keep a single-message
    format for maximum compatibility across model sizes.
    """
    categories = ", ".join(CATEGORIES)
    return (
        "Определи, является ли это сообщением о городской проблеме в Нижневартовске. "
        "Верни только JSON с полями relevant, category, address, summary, severity, priority, location_hints. "
        f"category выбери строго из этого списка: {categories}. "
        "Если есть пожар, дым, взрыв, открытое горение или явная угроза жизни, category должен быть ЧП. "
        "address укажи только если он явно есть в тексте, иначе null. "
        "summary сделай коротким нейтральным описанием до 12 слов без слов срочно, приоритет, требуется проверка. "
        "severity только 1, 2 или 3. priority только низкий, средний или высокий. "
        f"Сообщение: {text[:1200]}"
    )


_SUMMARY_NOISE_PATTERNS = (
    r"(?i)\bсрочно\b",
    r"(?i)\burgent\b",
    r"(?i)\bприоритет(?:\s*[:\-]?\s*(?:низкий|средний|высокий))?\b",
    r"(?i)\bприор\.\s*(?:низкий|средний|высокий)\b",
    r"(?i)\bтребуется проверка\b",
    r"(?i)\bтребует проверки\b",
    r"(?i)\bнужна проверка\b",
    r"(?i)\bнуждается в проверке\b",
    r"(?i)^проблема\s*(?:\([^)]*\))?\s*:\s*",
    r"(?i)^жалоба\s*(?:\([^)]*\))?\s*:\s*",
)

_SUMMARY_BANNED_VALUES = {
    "и разбор ситуации",
    "разбор ситуации",
    "описание ситуации",
    "городская проблема",
    "проблема",
    "сообщение",
}

_SUMMARY_ACTION_HINTS = (
    "не ",
    "нет ",
    "горит",
    "горени",
    "проис",
    "теч",
    "затоп",
    "застр",
    "слом",
    "повреж",
    "авар",
    "дым",
    "пожар",
    "яма",
    "гряз",
    "снег",
    "налед",
    "мусор",
    "обруш",
    "угроз",
    "закрыт",
    "заблок",
    "невозмож",
    "очист",
)


def make_marker_summary(text: str | None, *, max_len: int = 120) -> str:
    """Build a short neutral description suitable for map markers."""
    cleaned = str(text or "").replace("\n", " ").replace("\r", " ").strip()
    for pattern in _SUMMARY_NOISE_PATTERNS:
        cleaned = re.sub(pattern, " ", cleaned)
    cleaned = re.sub(
        r"^\d{1,2}\.\d{1,2}(?:\.\d{2,4})?\s*г?\.?(?:\s*в\s*\d{1,2}\s*час[^,.!?]*)?[,:;\-\s]*",
        "",
        cleaned,
    )
    cleaned = re.sub(
        r"^(?:г\.\s*[А-Яа-яЁёA-Za-z\-\s]+,\s*)?(?:ул\.|улица|проспект|пр-т|пер\.|мкр\.|микрорайон|наб\.)[^.!?]{0,120}\.\s*",
        "",
        cleaned,
        flags=re.IGNORECASE,
    )
    cleaned = re.sub(r"^[^\wа-яёА-ЯЁ]+", "", cleaned)
    cleaned = re.sub(r"\b(г|ул|д|мкр|пер|наб)\.\s*", r"\1 ", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s+", " ", cleaned).strip(" .,:;!-")
    if cleaned.lower() in _SUMMARY_BANNED_VALUES:
        return ""
    if cleaned:
        sentences = [
            sentence.strip(" .,:;!-")
            for sentence in re.split(r"(?<=[.!?])\s+", cleaned)
            if sentence.strip(" .,:;!-")
        ]
        picked = ""
        for sentence in sentences:
            lowered = sentence.lower()
            if len(sentence) < 18:
                continue
            if lowered in _SUMMARY_BANNED_VALUES:
                continue
            if re.fullmatch(r"[\d\s.:/\-]+", sentence):
                continue
            if ("ул." in lowered or "д." in lowered or "подъезд" in lowered) and not any(
                hint in lowered for hint in _SUMMARY_ACTION_HINTS
            ):
                continue
            picked = sentence
            break
        cleaned = picked or (sentences[0] if sentences else cleaned)
    if cleaned.lower() in _SUMMARY_BANNED_VALUES:
        return ""
    if len(cleaned) > max_len:
        cleaned = cleaned[: max_len - 3].rstrip(" ,.;:-") + "..."
    return cleaned


def build_marker_summary(summary: str | None, text: str | None, *, max_len: int = 120) -> str:
    """Pick a short, readable marker summary from AI output or raw post text."""
    cleaned_summary = make_marker_summary(summary, max_len=max_len)
    if cleaned_summary:
        return cleaned_summary

    fallback = ""
    for raw_line in re.split(r"[\r\n]+", str(text or "")):
        line = raw_line.strip()
        if not line:
            continue
        if re.match(r"^\d{1,2}\.\d{1,2}(?:\.\d{2,4})?\b", line):
            continue
        candidate = make_marker_summary(line, max_len=max_len)
        if not candidate:
            continue
        lowered = candidate.lower()
        if len(candidate) < 18:
            continue
        if ("ул " in lowered or "ул." in lowered or "д " in lowered or "д." in lowered or "подъезд" in lowered) and not any(
            hint in lowered for hint in _SUMMARY_ACTION_HINTS
        ):
            if not fallback:
                fallback = candidate
            continue
        if any(hint in lowered for hint in _SUMMARY_ACTION_HINTS):
            return candidate
        if not fallback:
            fallback = candidate

    return fallback or make_marker_summary(text, max_len=max_len)


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
    timeout: float = 60.0,
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
            async with get_http_client(timeout=timeout, proxy=px) as client:
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


async def _zai_analyze(text: str) -> Optional[Dict[str, Any]]:
    """Analyze via ZAI GLM-5 Turbo using the official OpenAI-compatible endpoint."""
    if not ZAI_API_KEY:
        return None

    cache_key = f"zai:{ZAI_TEXT_MODEL}"
    cached = get_cached_text(text, cache_key)
    if cached:
        return cached

    payload = {
        "model": ZAI_TEXT_MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": _make_prompt(text)},
        ],
        "temperature": 0.1,
        "max_tokens": 400,
        "stream": False,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Authorization": f"Bearer {ZAI_API_KEY}",
        "Content-Type": "application/json",
    }

    content = await _call_ai_api(
        f"{ZAI_BASE}/chat/completions",
        payload,
        headers,
        "ZAI",
        timeout=ZAI_REQUEST_TIMEOUT,
    )
    if not content:
        logger.warning("ZAI: all attempts failed")
        return None

    result = _parse_json(content)
    if result:
        logger.info("ZAI (%s): category=%s", ZAI_TEXT_MODEL, result.get("category"))
        set_cached_text(text, result, cache_key)
    return result


async def _litellm_analyze(text: str) -> Optional[Dict[str, Any]]:
    """Analyze via local LiteLLM/Ollama proxy with caching."""
    cached = get_cached_text(text, f"litellm:{LITELLM_TEXT_MODEL}")
    if cached:
        return cached

    use_compact_prompt = LITELLM_TEXT_MODEL in {"qwen-mini", "qwen-batch"} or LITELLM_TEXT_MODEL.startswith("qwen") or LITELLM_TEXT_MODEL.startswith("gemma")
    messages = (
        [{"role": "user", "content": _make_ollama_prompt(text)}]
        if use_compact_prompt
        else [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": _make_prompt(text)},
        ]
    )
    payload = {
        "model": LITELLM_TEXT_MODEL,
        "messages": messages,
        "temperature": 0.1,
        "stream": False,
        "max_tokens": 220,
    }
    headers = {
        "Content-Type": "application/json",
    }
    if LITELLM_MASTER_KEY:
        headers["Authorization"] = f"Bearer {LITELLM_MASTER_KEY}"

    for base_url in LITELLM_URLS:
        content = await _call_ai_api(
            f"{base_url}/chat/completions",
            payload,
            headers,
            f"LiteLLM({base_url})",
            timeout=LITELLM_REQUEST_TIMEOUT,
        )
        if not content:
            continue

        result = _parse_json(content)
        if result:
            logger.info("LiteLLM (%s): category=%s", LITELLM_TEXT_MODEL, result.get("category"))
            set_cached_text(text, result, f"litellm:{LITELLM_TEXT_MODEL}")
            return result

    return None


async def _ollama_analyze(text: str) -> Optional[Dict[str, Any]]:
    """Analyze directly via Ollama to avoid proxy-specific failures on low-spec hosts."""
    cache_key = f"ollama:{OLLAMA_TEXT_MODEL}"
    cached = get_cached_text(text, cache_key)
    if cached:
        return cached

    payload = {
        "model": OLLAMA_TEXT_MODEL,
        "prompt": _make_ollama_prompt(text),
        "stream": False,
        "format": "json",
        "options": {
            "temperature": 0,
            "num_predict": 180,
        },
    }

    for base_url in OLLAMA_URLS:
        try:
            async with get_http_client(timeout=OLLAMA_REQUEST_TIMEOUT, proxy=False) as client:
                r = await client.post(f"{base_url}/api/generate", json=payload)

            if r.status_code != 200:
                logger.warning("Ollama(%s) HTTP %d: %s", base_url, r.status_code, r.text[:200])
                continue

            data = r.json()
            content = str(data.get("response") or "").strip()
            if not content:
                continue

            result = _parse_json(content)
            if result:
                result = _blend_with_keyword_hint(text, result)
                logger.info("Ollama (%s): category=%s", OLLAMA_TEXT_MODEL, result.get("category"))
                set_cached_text(text, result, cache_key)
                return result
        except Exception as e:
            logger.debug("Ollama(%s) error: %s", base_url, e)

    return None


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


def _strong_keyword_hint(text: str) -> Dict[str, Any]:
    """UTF-8-safe fallback hints for the most common city complaint classes."""
    source = (text or "").lower()

    hint_map = [
        ("ЧП", ("пожар", "горит", "горение", "дым", "взрыв", "задымление"), 3, "высокий"),
        ("Дороги", ("яма", "выбоина", "асфальт", "дорог", "по встречке"), 2, "средний"),
        ("Освещение", ("освещение", "фонарь", "темно", "не горит свет", "лампа"), 2, "средний"),
        ("Бытовой мусор", ("мусор", "контейнер", "свалка", "отход"), 2, "средний"),
        ("Лифты и подъезды", ("лифт", "подъезд", "домофон"), 2, "средний"),
        ("Водоснабжение и канализация", ("течь", "затоп", "канализац", "труба", "прорыв"), 3, "высокий"),
        ("Снег/Наледь", ("снег", "наледь", "гололед", "сугроб"), 2, "средний"),
    ]

    category = "Прочее"
    severity = 1
    priority = "низкий"
    for cat, keywords, sev, prio in hint_map:
        if any(keyword in source for keyword in keywords):
            category = cat
            severity = sev
            priority = prio
            break

    address = None
    patterns = [
        r"(?:ул(?:ица)?\.?\s+)([А-Яа-яЁёA-Za-z0-9\-\s]+?)\s*,?\s*(\d+[А-Яа-яЁёA-Za-z]?)",
        r"(?:на\s+улице\s+)([А-Яа-яЁёA-Za-z0-9\-\s]+?)\s+(\d+[А-Яа-яЁёA-Za-z]?)",
        r"(?:на\s+проспекте\s+)([А-Яа-яЁёA-Za-z0-9\-\s]+?)\s+(\d+[А-Яа-яЁёA-Za-z]?)",
    ]
    for pattern in patterns:
        match = re.search(pattern, text or "", re.IGNORECASE)
        if match:
            address = f"ул. {match.group(1).strip()} {match.group(2).strip()}, Нижневартовск"
            break

    return {
        "category": category,
        "address": address,
        "summary": build_marker_summary(None, text, max_len=120),
        "relevant": category != "Прочее",
        "location_hints": None,
        "severity": severity,
        "priority": priority,
        "method": "keyword_utf8",
    }


def _blend_with_keyword_hint(text: str, result: Dict[str, Any]) -> Dict[str, Any]:
    """Repair weak local-model output using deterministic city-domain hints."""
    merged = dict(result or {})
    hint = _strong_keyword_hint(text)

    raw_category = str(merged.get("category") or "").strip()
    if raw_category not in CATEGORIES or (
        raw_category in {"ЖКХ", "Прочее"} and hint.get("category") not in {"ЖКХ", "Прочее"}
    ):
        merged["category"] = hint.get("category")

    if not merged.get("relevant") and hint.get("relevant"):
        merged["relevant"] = True

    if not merged.get("address") and hint.get("address"):
        merged["address"] = hint.get("address")

    summary = build_marker_summary(merged.get("summary"), text, max_len=120)
    if not summary or summary.lower() in _SUMMARY_BANNED_VALUES:
        summary = build_marker_summary(hint.get("summary"), text, max_len=120)
    if summary:
        merged["summary"] = summary

    try:
        merged["severity"] = max(int(merged.get("severity") or 1), int(hint.get("severity") or 1))
    except Exception:
        merged["severity"] = hint.get("severity") or 1

    if str(merged.get("priority") or "").strip().lower() not in {"низкий", "средний", "высокий"}:
        merged["priority"] = hint.get("priority")

    if merged.get("location_hints") in (None, "", "null") and hint.get("location_hints"):
        merged["location_hints"] = hint.get("location_hints")

    return merged


# --- Public API ---


def get_ai_provider() -> str:
    """Current active text analysis provider."""
    return AI_TEXT_PROVIDER


def set_ai_provider(provider: str) -> bool:
    """Switch active provider at runtime (no restart required)."""
    global AI_TEXT_PROVIDER
    p = (provider or "").strip().lower()
    if p not in ("zai", "litellm", "ollama", "keyword"):
        return False
    AI_TEXT_PROVIDER = p
    logger.info("AI text provider switched to: %s", AI_TEXT_PROVIDER)
    return True


def get_ai_provider_status() -> Dict[str, Any]:
    """Provider status for admin panel."""
    return {
        "active": AI_TEXT_PROVIDER,
        "zai_configured": bool(ZAI_API_KEY),
        "zai_model": ZAI_TEXT_MODEL,
        "zai_base": ZAI_BASE,
        "litellm_configured": bool(LITELLM_URLS),
        "litellm_model": LITELLM_TEXT_MODEL,
        "litellm_url": LITELLM_URLS[0] if LITELLM_URLS else None,
        "ollama_configured": bool(OLLAMA_URLS),
        "ollama_model": OLLAMA_TEXT_MODEL,
        "ollama_url": OLLAMA_URLS[0] if OLLAMA_URLS else None,
    }


async def analyze_complaint(text: str) -> Dict[str, Any]:
    """
    Analyze a complaint using the configured provider chain with fallback.

    Returns dict: relevant, category, address, summary, severity, priority,
    location_hints, provider.
    """
    order: List[str]
    if AI_TEXT_PROVIDER == "zai":
        order = ["zai", "litellm", "ollama", "keyword"]
    elif AI_TEXT_PROVIDER == "ollama":
        order = ["ollama", "keyword"]
    elif AI_TEXT_PROVIDER == "litellm":
        order = ["litellm", "keyword"]
    else:
        order = ["keyword"]

    for provider in order:
        if provider == "zai":
            result = await _zai_analyze(text)
            if result:
                result["provider"] = f"zai:{ZAI_TEXT_MODEL}"
                return _normalize_result(result)
        elif provider == "litellm":
            result = await _litellm_analyze(text)
            if result:
                result["provider"] = f"litellm:{LITELLM_TEXT_MODEL}"
                return _normalize_result(result)
        elif provider == "ollama":
            result = await _ollama_analyze(text)
            if result:
                result["provider"] = f"ollama:{OLLAMA_TEXT_MODEL}"
                return _normalize_result(result)
        elif provider == "keyword":
            break

    logger.warning("AI providers unavailable, using keyword analysis")
    result = _keyword_analyze(text)
    result["provider"] = "keyword"
    return _normalize_result(result)


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

    summary = make_marker_summary(result.get("summary"))
    if summary:
        result["summary"] = summary

    # Clean location_hints
    if result.get("location_hints") in (None, "null", "нет", "-", ""):
        result["location_hints"] = None

    return result


# --- Convenience wrappers ---


async def analyze_complaint_with_llm(text: str) -> Dict[str, Any]:
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
