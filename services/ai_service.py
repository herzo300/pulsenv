import os
from typing import Any, Dict
from services.zai_service import analyze_complaint

_api_key = os.getenv("ZAI_API_KEY", "")


async def analyze_complaint_v1(text: str) -> Dict[str, Any]:
    """
    Анализирует текст жалобы через Zai GLM-4.7.
    Возвращает JSON с категорией, адресом и резюме.
    """
    return await analyze_complaint(text)


async def analyze_complaint_v2(text: str) -> Dict[str, Any]:
    """
    Альтернативная версия анализа через Zai.
    """
    return await analyze_complaint(text)


class AIAnalyzer:
    """Класс для работы с AI анализом"""

    @staticmethod
    async def analyze(text: str) -> Dict[str, Any]:
        """Анализ текста жалобы"""
        return await analyze_complaint(text)

    @staticmethod
    async def categorize(text: str) -> str:
        """Определить категорию жалобы"""
        result = await analyze_complaint(text)
        return result.get("category", "Прочее")

    @staticmethod
    async def extract_address(text: str) -> str | None:
        """Извлечь адрес из текста"""
        result = await analyze_complaint(text)
        return result.get("address")


def get_ai_service():
    """
    Фабрика для получения AI сервиса.
    Можно расширить для поддержки разных моделей.
    """
    return AIAnalyzer()
