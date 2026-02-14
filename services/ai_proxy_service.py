# services/ai_proxy_service.py
"""
Unified AI Proxy Service

Интеграция claude-code-proxy для единого доступа к AI провайдерам:
- Zai GLM-4.7 (primary)
- OpenAI GPT-4 (fallback 1)
- Anthropic Claude (fallback 2)
"""

import httpx
import asyncio
from typing import Dict, Any, Optional

class AIProxyService:
    """Unified AI Proxy через claude-code-proxy"""

    def __init__(self, proxy_url: str = "http://127.0.0.1:5000"):
        self.proxy_url = proxy_url
        self.session = httpx.AsyncClient(timeout=30.0)

    async def analyze_complaint(
        self,
        text: str,
        provider: str = "zai",  # zai, openai, anthropic
        model: str = "haiku"  # haiku, sonnet, gpt-4
    ) -> Dict[str, Any]:
        """
        AI анализ жалоб через unified proxy

        Args:
            text: Текст жалобы
            provider: AI провайдер (zai/openai/anthropic)
            model: Модель (haiku/sonnet/gpt-4)

        Returns:
            Dict с category, address, summary
        """
        try:
            response = await self.session.post(
                f"{self.proxy_url}/v1/complaints/analyze",
                json={
                    "text": text,
                    "provider": provider,
                    "model": model,
                    "temperature": 0.1,
                    "max_tokens": 300,
                },
                timeout=30.0
            )
            response.raise_for_status()
            data = response.json()

            return {
                "category": data.get("category", "Прочее"),
                "address": data.get("address"),
                "summary": data.get("summary", text[:100]),
                "provider_used": data.get("provider", provider),
                "model_used": data.get("model", model),
            }

        except httpx.HTTPStatusError as e:
            print(f"AI proxy error: {e.response.status_code}")
            # Fallback на прямой Zai
            from services.zai_service import analyze_complaint
            return await analyze_complaint(text)

        except Exception as e:
            print(f"AI proxy error: {e}")
            return {
                "category": "Прочее",
                "address": None,
                "summary": text[:100],
                "provider_used": "zai_direct",
                "model_used": "glm-4.7-flash",
            }

    async def categorize(
        self,
        text: str,
        categories: list = None,
        provider: str = "zai"
    ) -> Optional[str]:
        """Категоризация через unified proxy"""
        try:
            result = await self.analyze_complaint(text, provider=provider)
            return result.get("category")
        except Exception as e:
            print(f"Categorization error: {e}")
            return None

    async def extract_address(
        self,
        text: str,
        provider: str = "zai"
    ) -> Optional[str]:
        """Извлечение адреса через unified proxy"""
        try:
            result = await self.analyze_complaint(text, provider=provider)
            return result.get("address")
        except Exception as e:
            print(f"Address extraction error: {e}")
            return None

    async def summarize(
        self,
        text: str,
        provider: str = "zai"
    ) -> Optional[str]:
        """Резюмирование через unified proxy"""
        try:
            result = await self.analyze_complaint(text, provider=provider)
            return result.get("summary")
        except Exception as e:
            print(f"Summarization error: {e}")
            return text[:100]

    async def get_stats(self) -> Dict[str, Any]:
        """Статистика использования AI"""
        try:
            response = await self.session.get(f"{self.proxy_url}/stats")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Stats error: {e}")
            return {
                "total_requests": 0,
                "requests_by_provider": {},
                "requests_by_model": {},
                "average_response_time_ms": 0,
            }

    async def health_check(self) -> bool:
        """Проверка доступности proxy"""
        try:
            response = await self.session.get(f"{self.proxy_url}/health")
            return response.status_code == 200
        except Exception as e:
            print(f"Health check failed: {e}")
            return False

    async def close(self):
        """Закрыть соединение"""
        await self.aclose()


# Singleton instance
_ai_proxy = None


async def get_ai_proxy() -> AIProxyService:
    """Получить singleton инстанс AI proxy"""
    global _ai_proxy
    if _ai_proxy is None:
        _ai_proxy = AIProxyService()
    return _ai_proxy
