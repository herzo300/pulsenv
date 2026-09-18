import json
import logging
from collections import defaultdict
from datetime import date
from typing import Optional

from services.ai.zai_service import (
    AI_TEXT_PROVIDER,
    OPENROUTER_API_KEY,
    OPENROUTER_BASE_URL,
    OPENROUTER_MODEL,
)
from core.http_client import get_http_client

logger = logging.getLogger(__name__)

class VIPMonthlyQuotaManager:
    def __init__(self, limit: int = 3):
        self.limit = limit
        self._usage = defaultdict(lambda: {"count": 0, "month": date.today().month, "year": date.today().year})

    def can_run(self, user_id: str) -> bool:
        record = self._usage[user_id]
        today = date.today()
        if record["month"] != today.month or record["year"] != today.year:
            record["count"] = 0
            record["month"] = today.month
            record["year"] = today.year
        
        if record["count"] >= self.limit:
            return False
            
        record["count"] += 1
        return True

legal_quota_manager = VIPMonthlyQuotaManager(limit=3)

LEGAL_SYSTEM_PROMPT = """Ты — высококвалифицированный юрист (VIP ИИ-Агент), специализирующийся на российском праве.
Твоя задача — составить грамотное, официальное юридическое обращение (жалобу, претензию или запрос) от имени жителя в компетентные органы (УК, Прокуратура, ГИБДД, Администрация города).
ПРАВИЛА:
1. Используй строгий официально-деловой стиль.
2. Ссылайся на Гражданский кодекс РФ (ГК РФ), Кодекс об административных правонарушениях (КоАП РФ), а также обязательно учитывай и ссылайся на локальные нормативные акты (правила благоустройства города и нормативные документы округа/региона).
3. Четко формулируй требования (провести проверку, устранить нарушение, привлечь к ответственности).
4. Структура: Шапка (кому, от кого - оставь пропуски [ФИО]), Суть проблемы, Правовое обоснование (со ссылками на статьи законов и местного самоуправления), Требования, Дата и подпись.
5. Верни результат в формате Markdown.
"""

async def generate_legal_appeal(complaint_text: str, category: str, address: Optional[str] = None, user_id: str = "vip_default") -> dict:
    """Генерирует юридически грамотное обращение на основе описания проблемы."""
    if not legal_quota_manager.can_run(user_id):
        return {"status": "error", "message": f"Лимит исчерпан: вам доступно составление {legal_quota_manager.limit} обращений в месяц."}

    if not complaint_text:
        return {"status": "error", "message": "Текст проблемы не предоставлен"}

    user_prompt = f"Категория проблемы: {category}\nАдрес: {address or 'Не указан'}\n\nОписание ситуации:\n{complaint_text}\n\nПожалуйста, составь официальное юридическое обращение."

    if AI_TEXT_PROVIDER == "openrouter" and OPENROUTER_API_KEY:
        try:
            async with get_http_client() as client:
                response = await client.post(
                    f"{OPENROUTER_BASE_URL}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                        "Content-Type": "application/json",
                        "HTTP-Referer": "https://soobshio.ru",
                        "X-Title": "City Pulse",
                    },
                    json={
                        "model": OPENROUTER_MODEL,
                        "messages": [
                            {"role": "system", "content": LEGAL_SYSTEM_PROMPT},
                            {"role": "user", "content": user_prompt},
                        ],
                    },
                    timeout=60.0
                )
                if response.status_code == 200:
                    data = response.json()
                    content = data["choices"][0]["message"]["content"]
                    return {"status": "success", "document": content}
                else:
                    return {"status": "error", "message": f"Ошибка AI: {response.text}"}
        except Exception as e:
            logger.error(f"Legal appeal generation error: {e}")
            return {"status": "error", "message": str(e)}
    
    # Фолбэк, если AI недоступен (или используется локальная LLM - можно добавить поддержку LiteLLM/Ollama аналогично)
    return {
        "status": "success", 
        "document": f"**Шаблон заявления**\n\nКатегория: {category}\nАдрес: {address or 'Не указан'}\n\nВ связи с недоступностью нейросети генерация текста временно ограничена.\n\nСуть проблемы:\n{complaint_text}"
    }
