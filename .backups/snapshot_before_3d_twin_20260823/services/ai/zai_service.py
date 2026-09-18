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
from typing import Any

from core.http_client import get_http_client, get_proxy_url
from services.ai.ai_cache import get_cached_text, set_cached_text

logger = logging.getLogger(__name__)


def _normalize_api_key(value: str) -> str:
    token = str(value or "").strip()
    if token.lower().startswith("z.ai "):
        token = token.split(" ", 1)[1].strip()
    return token


# Canonical list of complaint categories (single source of truth)
CATEGORIES: list[str] = [
    "ЧП",
    "ЖКХ",
    "Дороги",
    "Освещение",
    "Транспорт",
    "Экология",
    "Безопасность",
    "Снег/Наледь",
    "Медицина",
    "Образование",
    "Парковки",
    "Строительство",
    "Животные",
    "Вещи",
    "Мероприятие",
    "Прочее",
]


# --- AI provider configuration ---

LITELLM_URL: str = os.getenv("LITELLM_URL", "http://litellm:4000").strip().rstrip("/")
LITELLM_TEXT_MODEL: str = (
    os.getenv("LITELLM_TEXT_MODEL", "gemma4-text").strip() or "gemma4-text"
)
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
OLLAMA_TEXT_MODEL: str = (
    os.getenv("OLLAMA_TEXT_MODEL", "gemma4:4b").strip() or "gemma4:4b"
)
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

# Google Gemini API configurations (Free Tier AI Studio)
GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "").strip()

# OpenRouter configurations
OPENROUTER_API_KEY: str = (
    os.getenv("openrouter_api_key")
    or os.getenv("OPENROUTER_API_KEY")
    or os.getenv("GEMMA_CLOUD_API_KEY")
    or os.getenv("OPENAI_API_KEY")
    or os.getenv("CURSOR_API")
    or ""
).strip()
OPENROUTER_BASE_URL: str = os.getenv("OPENAI_BASE_URL", "https://openrouter.ai/api/v1").strip().rstrip("/")
OPENROUTER_MODEL: str = os.getenv("OPENROUTER_MODEL", "google/gemini-2.5-flash").strip()

AI_TEXT_PROVIDER: str = os.getenv("AI_TEXT_PROVIDER", "").strip().lower()
if AI_TEXT_PROVIDER not in ("gemini", "openrouter", "litellm", "ollama", "keyword"):
    # Detect configured provider: OpenRouter -> Gemini -> LiteLLM -> Ollama -> Keyword
    if OPENROUTER_API_KEY:
        AI_TEXT_PROVIDER = "openrouter"
    elif GEMINI_API_KEY:
        AI_TEXT_PROVIDER = "gemini"
    elif LITELLM_URLS:
        AI_TEXT_PROVIDER = "litellm"
    elif OLLAMA_URLS:
        AI_TEXT_PROVIDER = "ollama"
    else:
        AI_TEXT_PROVIDER = "keyword"

logger.info("Active AI text provider: %s", AI_TEXT_PROVIDER)

# --- System prompt and user prompt ---
SYSTEM_PROMPT: str = (
    "Ты — глубокий аналитик городских проблем Нижневартовска. "
    "Твоя задача: анализировать входящие сообщения и определять, являются ли они РЕАЛЬНОЙ городской проблемой или информацией о потерянных/найденных животных или вещах.\n\n"
    "ПРАВИЛА (СТРОГО):\n"
    "1. ТЕРМИНОЛОГИЯ: Используй термин 'городская проблема' вместо 'жалоба'.\n"
    "2. ОТКЛОНЯЙ (relevant=false): рекламу, продажи, вакансии, розыгрыши, мемы, "
    "шутки, анекдоты, поздравления, опросы, новости без конкретной проблемы, "
    "политику без городской проблемы.\n"
    "3. ПРИНИМАЙ (relevant=true): проблемы ЖКХ, дорог, транспорта, освещения, мусора, "
    "аварии, ЧП, поломки, опасные ситуации, проблемы благоустройства, а также "
    "объявления о потере или находке животных и вещей (для них используй категории: 'Животные', 'Вещи').\n"
    "4. АДРЕС: извлекай точный адрес (улица, дом). Если не уверен на 100% — пиши null.\n"
    "5. СЕРЬЁЗНОСТЬ (severity): оценивай по шкале 1-3. Крупные аварии, ДТП, обнаружение трупов, гибель людей или явные угрозы жизни — это критический уровень (severity=3).\n"
    "6. ГЛУБОКИЙ АНАЛИЗ: Не используй типовые фразы. Описывай ситуацию своими словами, "
    "вникая в детали и последствия.\n\n"
    "Отвечай ТОЛЬКО валидным JSON без markdown."
)


def _make_prompt(text: str) -> str:
    """Build the user prompt for AI analysis."""
    return (
        f"Проанализируй сообщение о городской ситуации в Нижневартовске.\n\n"
        f"Категории: {', '.join(CATEGORIES)}\n\n"
        f'Текст сообщения:\n"""\n{text[:1500]}\n"""\n\n'
        f"Определи:\n"
        f"1. relevant — это реальная городская проблема? (true/false)\n"
        f"2. category — категория из списка (если relevant=true)\n"
        f"3. address — точный адрес. Если не уверен на 100% — null.\n"
        f"4. title — краткий, понятный заголовок сигнала (до 5-8 слов, например: 'Порыв трубы отопления', 'Авария с участием автобуса', 'Обнаружен труп собаки во дворе').\n"
        f"5. description — подробное описание ситуации своими словами (перепиши исходный текст более грамотно, убрав нецензурную лексику и лишние эмоции, но полностью сохранив суть). Никаких советов, законов и аналитики от ИИ добавлять не нужно.\n"
        f"СТРОГО ЗАПРЕЩЕНО указывать источник сообщения, ссылки на каналы или паблики (например 'Источник: ...', 'По информации паблика...'). Запрещено копировать предложения из исходного текста паблика напрямую! Обязательно заканчивай описание до конца.\n"
        f"6. severity — оценка серьёзности (1, 2 или 3). ДТП, крупные аварии, трупы, гибель людей оцениваются строго как severity=3.\n"
        f"7. priority — 'низкий', 'средний' или 'высокий'. Для ДТП, крупных аварий и обнаружения трупов приоритет строго 'высокий'.\n"
        f"8. location_hints — ориентиры, если адрес неточный.\n\n"
        f'Верни JSON: {{"relevant":true/false,"category":"...","address":"...или null",'
        f'"title":"...","description":"...","severity":1/2/3,"priority":"...","location_hints":"..."}}'
    )


def _detect_city(text: str) -> str:
    t = str(text or "").lower()
    nsk_keywords = [
        "новосибирск", "нск", "колывань", "обь", "академгородок", "бердск",
        "димитровский мост", "красный проспект", "дуси ковальчук", "бориса богаткова",
        "хилокск", "затулин", "плющихин", "родники", "мжк", "студенческая", "речной вокзал",
        "октябрьский мост", "коммунальный мост", "первомайск", "калининск", "дзержинск",
        "заельцовск", "кировск", "ленинск", "советск"
    ]
    if any(kw in t for kw in nsk_keywords):
        return "novosibirsk"
    return "nizhnevartovsk"


def _get_prompts(text: str) -> tuple[str, str]:
    city = _detect_city(text)
    if city == "novosibirsk":
        sys_prompt = (
            "Ты — глубокий аналитик городских проблем Новосибирска. "
            "Твоя задача: анализировать входящие сообщения и определять, являются ли они РЕАЛЬНОЙ городской проблемой или информацией о потерянных/найденных животных или вещах.\n\n"
            "ПРАВИЛА (СТРОГО):\n"
            "1. ТЕРМИНОЛОГИЯ: Используй термин 'городская проблема' вместо 'жалоба'.\n"
            "2. ОТКЛОНЯЙ (relevant=false): рекламу, продажи, вакансии, розыгрыши, мемы, "
            "шутки, анекдоты, поздравления, опросы, новости без конкретной проблемы, "
            "политику без городской проблемы.\n"
            "3. ПРИНИМАЙ (relevant=true): проблемы ЖКХ, дорог, транспорта, освещения, мусора, "
            "аварии, ЧП, поломки, опасные ситуации, проблемы благоустройства, а также "
            "объявления о потере или находке животных и вещей (для них используй категории: 'Животные', 'Вещи').\n"
            "4. АДРЕС: извлекай точный адрес (улица, дом). Если не уверен на 100% — пиши null.\n"
            "5. СЕРЬЁЗНОСТЬ (severity): оценивай по шкале 1-3. Крупные аварии, ДТП, обнаружение трупов, гибель людей или явные угрозы жизни — это критический уровень (severity=3).\n"
            "6. ГЛУБОКИЙ АНАЛИЗ: Не используй типовые фразы. Описывай ситуацию своими словами, "
            "вникая в детали и последствия. На основе адреса/ориентиров в тексте определи и укажи район или микрорайон Новосибирска (например: Ленинский район, Октябрьский район, Затулинка, Академгородок, Родники, МЖК и т.д.).\n\n"
            "Отвечай ТОЛЬКО валидным JSON без markdown."
        )
        user_prompt = (
            f"Проанализируй сообщение о городской ситуации в Новосибирске.\n\n"
            f"Категории: {', '.join(CATEGORIES)}\n\n"
            f'Текст сообщения:\n"""\n{text[:1500]}\n"""\n\n'
            f"Определи:\n"
            f"1. relevant — это реальная городская проблема? (true/false)\n"
            f"2. category — категория из списка (если relevant=true)\n"
            f"3. address — точный адрес. Если не уверен на 100% — null.\n"
            f"4. title — краткий, понятный заголовок сигнала (до 5-8 слов).\n"
            f"5. description — подробное описание ситуации своими словами (перепиши исходный текст более грамотно, убрав нецензурную лексику и лишние эмоции, но полностью сохранив суть). Обязательно определи микрорайон/район Новосибирска и укажи его в описании. Никаких советов, законов и аналитики от ИИ добавлять не нужно.\n"
            f"Запрещено копировать предложения напрямую! Обязательно заканчивай описание до конца.\n"
            f"6. severity — оценка серьёзности (1, 2 или 3).\n"
            f"7. priority — 'низкий', 'средний' или 'высокий'.\n"
            f"8. location_hints — ориентиры, если адрес неточный.\n\n"
            f'Верни JSON: {{"relevant":true/false,"category":"...","address":"...или null",'
            f'"title":"...","description":"...","severity":1/2/3,"priority":"...","location_hints":"..."}}'
        )
    else:
        sys_prompt = SYSTEM_PROMPT
        user_prompt = _make_prompt(text)
    return sys_prompt, user_prompt


def _make_ollama_prompt(text: str) -> str:
    """Compact prompt for local Ollama models (Gemma 4 / qwen) adapting to city context."""
    city = _detect_city(text)
    city_name = "Новосибирске" if city == "novosibirsk" else "Нижневартовске"
    categories = ", ".join(CATEGORIES)
    district_hint = " Обязательно определи и укажи микрорайон/район Новосибирска (например, Ленинский район, Октябрьский район, Затулинка, Родники, Академгородок) в описании." if city == "novosibirsk" else ""
    return (
        f"Определи, является ли это сообщением о городской проблеме в {city_name}. "
        "Верни только JSON с полями relevant, category, address, title, description, severity, priority, location_hints. "
        f"category выбери строго из этого списка: {categories}. "
        "Если в тексте упоминается труп, смерть, погибший, авария или ДТП, category должен быть ЧП, severity=3, priority='высокий'. "
        "address укажи только если он явно есть в тексте, иначе null. "
        "В title напиши краткий заголовок сигнала (до 5-8 слов). "
        f"В description напиши подробное описание ситуации своими словами (перепиши исходный текст более грамотно, убрав эмоции, но сохранив суть){district_hint}. Никаких советов и аналитики добавлять не нужно. "
        "Обязательно заканчивай описание до конца и ставь точку в конце. "
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
    cleaned = re.sub(
        r"\b(г|ул|д|мкр|пер|наб)\.\s*", r"\1 ", cleaned, flags=re.IGNORECASE
    )
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
            if (
                "ул." in lowered or "д." in lowered or "подъезд" in lowered
            ) and not any(hint in lowered for hint in _SUMMARY_ACTION_HINTS):
                continue
            picked = sentence
            break
        cleaned = picked or (sentences[0] if sentences else cleaned)
    if cleaned.lower() in _SUMMARY_BANNED_VALUES:
        return ""
    if len(cleaned) > max_len:
        cleaned = cleaned[: max_len - 3].rstrip(" ,.;:-") + "..."
    return cleaned


def build_marker_summary(
    summary: str | None, text: str | None, *, max_len: int = 120
) -> str:
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
        if (
            "ул " in lowered
            or "ул." in lowered
            or "д " in lowered
            or "д." in lowered
            or "подъезд" in lowered
        ) and not any(hint in lowered for hint in _SUMMARY_ACTION_HINTS):
            if not fallback:
                fallback = candidate
            continue
        if any(hint in lowered for hint in _SUMMARY_ACTION_HINTS):
            return candidate
        if not fallback:
            fallback = candidate

    return fallback or make_marker_summary(text, max_len=max_len)


def _parse_json(text: str) -> dict[str, Any] | None:
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
) -> str | None:
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
                logger.warning(
                    "%s [%s] HTTP %d: %s", label, mode, r.status_code, r.text[:200]
                )
                continue

            data = r.json()
            msg = data.get("choices", [{}])[0].get("message", {})
            content = msg.get("content") or msg.get("reasoning_content") or ""
            if content:
                return content
        except Exception as e:
            logger.debug("%s [%s] error: %s", label, mode, e)

    return None


# ZAI analysis function removed (migrated to OpenRouter)


async def _litellm_analyze(text: str) -> dict[str, Any] | None:
    """Analyze via local LiteLLM/Ollama proxy with caching."""
    cached = get_cached_text(text, f"litellm:{LITELLM_TEXT_MODEL}")
    if cached:
        return cached

    use_compact_prompt = (
        LITELLM_TEXT_MODEL in {"qwen-mini", "qwen-batch"}
        or LITELLM_TEXT_MODEL.startswith("qwen")
        or LITELLM_TEXT_MODEL.startswith("gemma")
    )
    sys_prompt, user_prompt = _get_prompts(text)
    messages = (
        [{"role": "user", "content": _make_ollama_prompt(text)}]
        if use_compact_prompt
        else [
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": user_prompt},
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
            logger.info(
                "LiteLLM (%s): category=%s", LITELLM_TEXT_MODEL, result.get("category")
            )
            set_cached_text(text, result, f"litellm:{LITELLM_TEXT_MODEL}")
            return result

    return None


async def _ollama_analyze(text: str) -> dict[str, Any] | None:
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
            async with get_http_client(
                timeout=OLLAMA_REQUEST_TIMEOUT, proxy=False
            ) as client:
                r = await client.post(f"{base_url}/api/generate", json=payload)

            if r.status_code != 200:
                logger.warning(
                    "Ollama(%s) HTTP %d: %s", base_url, r.status_code, r.text[:200]
                )
                continue

            data = r.json()
            content = str(data.get("response") or "").strip()
            if not content:
                continue

            result = _parse_json(content)
            if result:
                result = _blend_with_keyword_hint(text, result)
                logger.info(
                    "Ollama (%s): category=%s",
                    OLLAMA_TEXT_MODEL,
                    result.get("category"),
                )
                set_cached_text(text, result, cache_key)
                return result
        except Exception as e:
            logger.debug("Ollama(%s) error: %s", base_url, e)

    return None


async def _gemini_text_analyze(text: str) -> dict[str, Any] | None:
    """Analyze via native Google Gemini API (AI Studio Free Tier) with caching."""
    if not GEMINI_API_KEY:
        return None

    cache_key = "gemini:gemini-2.5-flash"
    cached = get_cached_text(text, cache_key)
    if cached:
        return cached

    sys_prompt, user_prompt = _get_prompts(text)
    payload = {
        "systemInstruction": {
            "parts": [
                {"text": sys_prompt}
            ]
        },
        "contents": [
            {
                "parts": [
                    {"text": user_prompt}
                ]
            }
        ],
        "generationConfig": {
            "responseMimeType": "application/json",
            "temperature": 0.1,
            "maxOutputTokens": 400,
        }
    }

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"
    
    try:
        async with get_http_client(timeout=30.0, proxy=False) as client:
            r = await client.post(url, json=payload)
            if r.status_code == 200:
                data = r.json()
                content = data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "").strip()
                if content:
                    result = _parse_json(content)
                    if result:
                        logger.info("Gemini text: category=%s", result.get("category"))
                        set_cached_text(text, result, cache_key)
                        return result
            else:
                logger.warning("Gemini text HTTP %d: %s", r.status_code, r.text[:200])
    except Exception as e:
        logger.debug("Gemini text API error: %s", e)
    return None


async def _openrouter_analyze(text: str) -> dict[str, Any] | None:
    """Analyze via OpenRouter (using free/cheap models) with caching."""
    if not OPENROUTER_API_KEY:
        return None

    cache_key = f"openrouter:{OPENROUTER_MODEL}"
    cached = get_cached_text(text, cache_key)
    if cached:
        return cached

    # We will try a sequence of models to handle rate-limiting (429) gracefully on free models:
    # 1. User preferred OPENROUTER_MODEL (usually gemini-2.5-flash which is paid/stable/cheap, or llama-3.3-70b:free)
    # 2. google/gemma-4-31b-it:free (stable Google free model)
    # 3. meta-llama/llama-3.2-3b-instruct:free (fast lightweight free model)
    # 4. qwen/qwen-2.5-7b-instruct (paid/extremely cheap $0.05/1M tokens fallback)
    models = [
        OPENROUTER_MODEL or "google/gemini-2.5-flash",
        "google/gemini-2.5-flash",
        "anthropic/claude-3.5-sonnet",
        "deepseek/deepseek-r1",
        "qwen/qwen-2.5-72b-instruct",
        "meta-llama/llama-3.3-70b-instruct",
    ]
    # Remove duplicates preserving order
    unique_models = []
    for m in models:
        if m and m not in unique_models:
            unique_models.append(m)

    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/Antigravity-City/pulsenv_project",
    }

    sys_prompt, user_prompt = _get_prompts(text)
    for model in unique_models:
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": sys_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "temperature": 0.1,
            "max_tokens": 400,
            "response_format": {"type": "json_object"}
        }
        try:
            content = await _call_ai_api(
                f"{OPENROUTER_BASE_URL}/chat/completions",
                payload,
                headers,
                f"OpenRouter({model})",
                timeout=30.0,
            )
            if content:
                result = _parse_json(content)
                if result:
                    logger.info("OpenRouter (%s): category=%s", model, result.get("category"))
                    # Cache the result with the active model key
                    set_cached_text(text, result, f"openrouter:{model}")
                    return result
        except Exception as e:
            logger.debug("OpenRouter (%s) exception: %s", model, e)

    return None


# --- Keyword rules for severity assignment ---
_HIGH_RISK_CATS = frozenset(
    {
        "ЧП",
        "Безопасность",
        "Газоснабжение",
        "Водоснабжение и канализация",
        "Отопление",
    }
)
_MEDIUM_RISK_CATS = frozenset(
    {
        "Дороги",
        "Снег/Наледь",
        "Освещение",
        "Бытовой мусор",
        "Лифты и подъезды",
        "Парки и скверы",
        "Детские площадки",
    }
)


def _keyword_analyze(text: str) -> dict[str, Any]:
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

    # Add emergency keywords (труп, авария, дтп, смерть, погиб) to elevate to ЧП/severity 3
    if any(kw in t for kw in ["труп", "авари", "дтп", "смерт", "погиб", "умер"]):
        category = "ЧП"

    # Address extraction via regex
    address = None
    for pat in [
        r"(?:ул(?:ица|ице)?\.?\s+)([А-Яа-яЁё]+(?:\s+[А-Яа-яЁё]+)?)\s*,?\s*(\d+[а-яА-Я]?)",
        r"(?:пр(?:оспект|оспекте)?\.?\s+)([А-Яа-яЁё]+(?:\s+[А-Яа-яЁё]+)?)\s*,?\s*(\d+[а-яА-Я]?)",
    ]:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            address = f"ул. {m.group(1)} {m.group(2)}, Нижневартовск"
            break

    # Severity based on category
    if category in _HIGH_RISK_CATS or category == "ЧП":
        severity, priority = 3, "высокий"
    elif category in _MEDIUM_RISK_CATS:
        severity, priority = 2, "средний"
    else:
        severity, priority = 1, "низкий"

    summary = f"Проблема ({category}, приор. {priority}): требуется проверка и разбор ситуации."

    return {
        "category": category,
        "address": address,
        "title": f"ЧП: {category}" if category == "ЧП" else f"Сигнал: {category}",
        "description": f"Зарегистрирована городская ситуация по категории {category}. Требуется выезд служб и проверка.",
        "summary": summary[:120],
        "relevant": category != "Прочее",
        "location_hints": None,
        "severity": severity,
        "priority": priority,
        "method": "keyword",
    }


def _strong_keyword_hint(text: str) -> dict[str, Any]:
    """UTF-8-safe fallback hints for the most common city complaint classes."""
    source = (text or "").lower()

    hint_map = [
        (
            "ЧП",
            ("пожар", "горит", "горение", "дым", "взрыв", "задымление", "труп", "авария", "дтп", "смерть", "погиб"),
            3,
            "высокий",
        ),
        ("Дороги", ("яма", "выбоина", "асфальт", "дорог", "по встречке"), 2, "средний"),
        (
            "Освещение",
            ("освещение", "фонарь", "темно", "не горит свет", "лампа"),
            2,
            "средний",
        ),
        ("Бытовой мусор", ("мусор", "контейнер", "свалка", "отход"), 2, "средний"),
        ("Лифты и подъезды", ("лифт", "подъезд", "домофон"), 2, "средний"),
        (
            "Водоснабжение и канализация",
            ("течь", "затоп", "канализац", "труба", "прорыв"),
            3,
            "высокий",
        ),
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

    # Force severity 3 and high priority for critical keywords
    if any(kw in source for kw in ["труп", "авари", "дтп", "смерт", "погиб"]):
        category = "ЧП"
        severity = 3
        priority = "высокий"

    address = None
    patterns = [
        r"(?:ул(?:ица)?\.?\s+)([А-Яа-яЁёA-Za-z0-9\-\s]+?)\s*,?\s*(\d+[А-Яа-яЁёA-Za-z]?)",
        r"(?:на\s+улице\s+)([А-Яа-яЁёA-Za-z0-9\-\s]+?)\s+(\d+[А-Яа-яЁёA-Za-z]?)",
        r"(?:на\s+проспекте\s+)([А-Яа-яЁёA-Za-z0-9\-\s]+?)\s+(\d+[А-Яа-яЁёA-Za-z]?)",
    ]
    for pattern in patterns:
        match = re.search(pattern, text or "", re.IGNORECASE)
        if match:
            address = (
                f"ул. {match.group(1).strip()} {match.group(2).strip()}, Нижневартовск"
            )
            break

    return {
        "category": category,
        "address": address,
        "title": f"ЧП: {category}" if category == "ЧП" else f"Сигнал: {category}",
        "description": f"Поступило автоматическое оповещение по категории {category}. Рекомендуется обратить внимание.",
        "summary": build_marker_summary(None, text, max_len=120),
        "relevant": category != "Прочее",
        "location_hints": None,
        "severity": severity,
        "priority": priority,
        "method": "keyword_utf8",
    }


def _blend_with_keyword_hint(text: str, result: dict[str, Any]) -> dict[str, Any]:
    """Repair weak local-model output using deterministic city-domain hints."""
    merged = dict(result or {})
    hint = _strong_keyword_hint(text)

    raw_category = str(merged.get("category") or "").strip()
    if raw_category not in CATEGORIES or (
        raw_category in {"ЖКХ", "Прочее"}
        and hint.get("category") not in {"ЖКХ", "Прочее"}
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
        merged["severity"] = max(
            int(merged.get("severity") or 1), int(hint.get("severity") or 1)
        )
    except Exception:
        merged["severity"] = hint.get("severity") or 1

    if str(merged.get("priority") or "").strip().lower() not in {
        "низкий",
        "средний",
        "высокий",
    }:
        merged["priority"] = hint.get("priority")

    if merged.get("location_hints") in (None, "", "null") and hint.get(
        "location_hints"
    ):
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
    if p not in ("gemini", "openrouter", "litellm", "ollama", "keyword"):
        return False
    AI_TEXT_PROVIDER = p
    logger.info("AI text provider switched to: %s", AI_TEXT_PROVIDER)
    return True


def get_ai_provider_status() -> dict[str, Any]:
    """Provider status for admin panel."""
    return {
        "active": AI_TEXT_PROVIDER,
        "gemini_configured": bool(GEMINI_API_KEY),
        "gemini_model": "gemini-2.5-flash",
        "openrouter_configured": bool(OPENROUTER_API_KEY),
        "openrouter_model": OPENROUTER_MODEL,
        "litellm_configured": bool(LITELLM_URLS),
        "litellm_model": LITELLM_TEXT_MODEL,
        "litellm_url": LITELLM_URLS[0] if LITELLM_URLS else None,
        "ollama_configured": bool(OLLAMA_URLS),
        "ollama_model": OLLAMA_TEXT_MODEL,
        "ollama_url": OLLAMA_URLS[0] if OLLAMA_URLS else None,
    }


async def analyze_complaint(text: str) -> dict[str, Any]:
    """
    Analyze a complaint using the configured provider chain with fallback.

    Returns dict: relevant, category, address, summary, severity, priority,
    location_hints, provider.
    """
    order: list[str]
    if AI_TEXT_PROVIDER == "gemini":
        order = ["gemini", "openrouter", "litellm", "ollama", "keyword"]
    elif AI_TEXT_PROVIDER == "openrouter":
        order = ["openrouter", "gemini", "litellm", "ollama", "keyword"]
    elif AI_TEXT_PROVIDER == "litellm":
        order = ["litellm", "keyword"]
    elif AI_TEXT_PROVIDER == "ollama":
        order = ["ollama", "keyword"]
    else:
        order = ["keyword"]

    for provider in order:
        if provider == "gemini":
            result = await _gemini_text_analyze(text)
            if result:
                result["provider"] = "gemini:gemini-2.5-flash"
                return _normalize_result(result)
        elif provider == "openrouter":
            result = await _openrouter_analyze(text)
            if result:
                result["provider"] = f"openrouter:{OPENROUTER_MODEL}"
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


def _normalize_result(result: dict[str, Any]) -> dict[str, Any]:
    """Normalize AI result: clean address, validate relevant field."""
    # Default relevant to True for backward compatibility
    if "relevant" not in result:
        result["relevant"] = True
    rel = result.get("relevant")
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
    summary = result.get("summary")
    if summary:
        for pattern in _SUMMARY_NOISE_PATTERNS:
            summary = re.sub(pattern, " ", summary)
        summary = re.sub(r"\s+", " ", summary).strip()
        result["summary"] = summary
    desc = result.get("description")
    if desc and isinstance(desc, str):
        desc = desc.strip()
        desc = re.sub(r'\n\s*\n', '\n', desc)
        desc = re.sub(r'\n+', '\n', desc)
        result["description"] = desc
    # Clean location_hints
    if result.get("location_hints") in (None, "null", "нет", "-", ""):
        result["location_hints"] = None
    return result

# --- Convenience wrappers ---

async def analyze_complaint_with_llm(text: str) -> dict[str, Any]:
    """Alias for analyze_complaint (backward compatibility)."""
    return await analyze_complaint(text)

def extract_categories_from_text(text: str) -> list[str]:
    """Extract matching categories from text."""
    return [c for c in CATEGORIES if c in text]


class AIAnalyzer:
    """Convenience wrapper class for AI analysis."""

    @staticmethod
    async def analyze(text: str) -> dict[str, Any]:
        return await analyze_complaint(text)

    @staticmethod
    async def categorize(text: str) -> str:
        return (await analyze_complaint(text)).get("category", "Прочее")

    @staticmethod
    async def extract_address(text: str) -> str | None:
        return (await analyze_complaint(text)).get("address")


def get_ai_service():
    """Get an AIAnalyzer instance."""
    return AIAnalyzer()


async def generate_text_using_llm(
    user_prompt: str,
    system_prompt: str = "Ты — помощник в городской системе Нижневартовска.",
    max_tokens: int = 200,
    temperature: float = 0.7,
    model: str = None,
) -> str | None:
    """
    Generate raw text from configured AI providers in order of fallback.
    """
    order = []
    if AI_TEXT_PROVIDER == "gemini":
        order = ["gemini", "openrouter", "litellm", "ollama"]
    elif AI_TEXT_PROVIDER == "openrouter":
        order = ["openrouter", "gemini", "litellm", "ollama"]
    elif AI_TEXT_PROVIDER == "litellm":
        order = ["litellm", "ollama"]
    elif AI_TEXT_PROVIDER == "ollama":
        order = ["ollama"]
    else:
        order = ["gemini", "openrouter", "litellm", "ollama"]

    for provider in order:
        if provider == "gemini" and GEMINI_API_KEY:
            payload = {
                "systemInstruction": {"parts": [{"text": system_prompt}]},
                "contents": [{"parts": [{"text": user_prompt}]}],
                "generationConfig": {
                    "temperature": temperature,
                    "maxOutputTokens": max_tokens,
                }
            }
            # If a custom model is requested, try to map it, otherwise default to gemini-2.5-flash
            gemini_model = "gemini-2.5-flash"
            if model:
                # Extract simple model name if full OpenRouter path passed (e.g. google/gemini-2.5-flash -> gemini-2.5-flash)
                gemini_model = model.split("/")[-1]
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{gemini_model}:generateContent?key={GEMINI_API_KEY}"
            try:
                async with get_http_client(timeout=30.0, proxy=False) as client:
                    r = await client.post(url, json=payload)
                    if r.status_code == 200:
                        data = r.json()
                        content = data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "").strip()
                        if content:
                            return content
            except Exception as e:
                logger.debug("Gemini generic text error: %s", e)

        elif provider == "openrouter" and OPENROUTER_API_KEY:
            headers = {
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://github.com/Antigravity-City/pulsenv_project",
            }
            payload = {
                "model": model or OPENROUTER_MODEL,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "temperature": temperature,
                "max_tokens": max_tokens,
            }
            try:
                content = await _call_ai_api(
                    f"{OPENROUTER_BASE_URL}/chat/completions",
                    payload,
                    headers,
                    f"OpenRouterGeneric({model or OPENROUTER_MODEL})",
                    timeout=30.0,
                )
                if content:
                    return content.strip()
            except Exception as e:
                logger.debug("OpenRouter generic text error: %s", e)

        elif provider == "litellm" and LITELLM_URLS:
            headers = {"Content-Type": "application/json"}
            if LITELLM_MASTER_KEY:
                headers["Authorization"] = f"Bearer {LITELLM_MASTER_KEY}"
            payload = {
                "model": LITELLM_TEXT_MODEL,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "temperature": temperature,
                "max_tokens": max_tokens,
            }
            for base_url in LITELLM_URLS:
                try:
                    content = await _call_ai_api(
                        f"{base_url}/chat/completions",
                        payload,
                        headers,
                        "LiteLLMGeneric",
                        timeout=30.0,
                    )
                    if content:
                        return content.strip()
                except Exception as e:
                    logger.debug("LiteLLM generic text error: %s", e)

        elif provider == "ollama" and OLLAMA_URLS:
            payload = {
                "model": OLLAMA_TEXT_MODEL,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "options": {
                    "temperature": temperature,
                    "num_predict": max_tokens,
                },
                "stream": False,
            }
            for base_url in OLLAMA_URLS:
                try:
                    async with get_http_client(timeout=30.0, proxy=False) as client:
                        r = await client.post(f"{base_url}/api/chat", json=payload)
                        if r.status_code == 200:
                            data = r.json()
                            content = data.get("message", {}).get("content", "").strip()
                            if content:
                                return content
                except Exception as e:
                    logger.debug("Ollama generic text error: %s", e)

    return None

