# services/ai_proxy_service.py
"""
Unified AI Proxy Service.

Provides a single interface to AI providers via claude-code-proxy:
- Zai GLM-4.7 (primary)
- OpenAI GPT-4 (fallback 1)
- Anthropic Claude (fallback 2)
"""

import logging
from typing import Any, Dict, Optional

import httpx

from core.http_client import get_http_client

logger = logging.getLogger(__name__)


class AIProxyService:
    """Unified AI Proxy via claude-code-proxy."""

    def __init__(self, proxy_url: str = "http://127.0.0.1:5000"):
        self.proxy_url = proxy_url
        self._client: Optional[httpx.AsyncClient] = None

    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None or self._client.is_closed:
            self._client = get_http_client(timeout=30.0)
        return self._client

    async def analyze_complaint(
        self,
        text: str,
        provider: str = "zai",
        model: str = "haiku",
    ) -> Dict[str, Any]:
        """
        AI complaint analysis via the unified proxy.

        Args:
            text: Complaint text.
            provider: AI provider (zai / openai / anthropic).
            model: Model name (haiku / sonnet / gpt-4).

        Returns:
            Dict with category, address, summary.
        """
        try:
            client = await self._get_client()
            response = await client.post(
                f"{self.proxy_url}/v1/complaints/analyze",
                json={
                    "text": text,
                    "provider": provider,
                    "model": model,
                    "temperature": 0.1,
                    "max_tokens": 300,
                },
                timeout=30.0,
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
            logger.warning("AI proxy HTTP error: %s", e.response.status_code)
            from services.zai_service import analyze_complaint

            return await analyze_complaint(text)
        except Exception as e:
            logger.warning("AI proxy error: %s", e)
            return {
                "category": "Прочее",
                "address": None,
                "summary": text[:100],
                "provider_used": "zai_direct",
                "model_used": "glm-4.7-flash",
            }

    async def categorize(
        self, text: str, categories: list = None, provider: str = "zai"
    ) -> Optional[str]:
        """Categorize text via unified proxy."""
        try:
            result = await self.analyze_complaint(text, provider=provider)
            return result.get("category")
        except Exception as e:
            logger.warning("Categorization error: %s", e)
            return None

    async def extract_address(
        self, text: str, provider: str = "zai"
    ) -> Optional[str]:
        """Extract address via unified proxy."""
        try:
            result = await self.analyze_complaint(text, provider=provider)
            return result.get("address")
        except Exception as e:
            logger.warning("Address extraction error: %s", e)
            return None

    async def summarize(self, text: str, provider: str = "zai") -> Optional[str]:
        """Summarize text via unified proxy."""
        try:
            result = await self.analyze_complaint(text, provider=provider)
            return result.get("summary")
        except Exception as e:
            logger.warning("Summarization error: %s", e)
            return text[:100]

    async def get_stats(self) -> Dict[str, Any]:
        """AI usage statistics."""
        try:
            client = await self._get_client()
            response = await client.get(f"{self.proxy_url}/stats")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.debug("Stats unavailable: %s", e)
            return {
                "total_requests": 0,
                "requests_by_provider": {},
                "requests_by_model": {},
                "average_response_time_ms": 0,
            }

    async def health_check(self) -> bool:
        """Check proxy availability."""
        try:
            client = await self._get_client()
            response = await client.get(f"{self.proxy_url}/health")
            return response.status_code == 200
        except Exception:
            return False

    async def close(self):
        """Close HTTP client."""
        if self._client and not self._client.is_closed:
            await self._client.aclose()
            self._client = None


# Singleton
_ai_proxy: Optional[AIProxyService] = None


async def get_ai_proxy() -> AIProxyService:
    """Get singleton AI proxy instance."""
    global _ai_proxy
    if _ai_proxy is None:
        _ai_proxy = AIProxyService()
    return _ai_proxy
