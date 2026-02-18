# services/mcp_fetch_service.py
"""
Интеграция с MCP Fetch Server для парсинга Telegram каналов и VK пабликов
Используется как альтернативный метод получения данных через веб-парсинг
"""

import asyncio
import logging
import os
import re
from typing import Dict, List, Optional, Any
from datetime import datetime
from urllib.parse import quote, urljoin

import httpx
from core.http_client import get_http_client
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# MCP Fetch Server конфигурация
MCP_FETCH_SERVER_URL = os.getenv("MCP_FETCH_SERVER_URL", "http://localhost:3000")
MCP_FETCH_ENABLED = os.getenv("MCP_FETCH_ENABLED", "false").lower() == "true"
MCP_FETCH_TIMEOUT = float(os.getenv("MCP_FETCH_TIMEOUT", "30.0"))


class MCPFetchService:
    """Сервис для работы с MCP Fetch Server"""
    
    def __init__(self, server_url: str = None, timeout: float = None):
        self.server_url = server_url or MCP_FETCH_SERVER_URL
        self.timeout = timeout or MCP_FETCH_TIMEOUT
        self.enabled = MCP_FETCH_ENABLED
        
    async def fetch_url(
        self,
        url: str,
        method: str = "GET",
        headers: Optional[Dict[str, str]] = None,
        params: Optional[Dict[str, Any]] = None,
        body: Optional[str] = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Выполняет HTTP запрос через MCP Fetch Server
        
        Args:
            url: URL для запроса
            method: HTTP метод (GET, POST, etc.)
            headers: Заголовки запроса
            params: Query параметры
            body: Тело запроса (для POST/PUT)
            
        Returns:
            Dict с результатом: {
                "status": int,
                "headers": dict,
                "body": str,
                "text": str,
                "json": dict (если применимо)
            }
        """
        if not self.enabled:
            logger.debug("MCP Fetch Server отключен")
            return None
            
        try:
            # Формируем URL для MCP Fetch Server
            fetch_url = f"{self.server_url}/fetch"
            
            payload = {
                "url": url,
                "method": method.upper(),
            }
            
            if headers:
                payload["headers"] = headers
                
            if params:
                # Добавляем params в URL
                query_string = "&".join([f"{k}={quote(str(v))}" for k, v in params.items()])
                if "?" in url:
                    payload["url"] = f"{url}&{query_string}"
                else:
                    payload["url"] = f"{url}?{query_string}"
                    
            if body:
                payload["body"] = body
                
            async with get_http_client(timeout=self.timeout) as client:
                response = await client.post(fetch_url, json=payload)
                
                if response.status_code == 200:
                    result = response.json()
                    return result
                else:
                    logger.error(f"MCP Fetch error: {response.status_code} - {response.text}")
                    return None
                    
        except Exception as e:
            logger.error(f"MCP Fetch request error: {e}")
            return None
    
    async def parse_html(
        self,
        url: str,
        selector: Optional[str] = None,
        extract_text: bool = True,
    ) -> Optional[Dict[str, Any]]:
        """
        Парсит HTML страницу через MCP Fetch Server
        
        Args:
            url: URL страницы
            selector: CSS селектор для извлечения элементов
            extract_text: Извлекать ли текст из элементов
            
        Returns:
            Dict с результатами парсинга
        """
        if not self.enabled:
            return None
            
        try:
            parse_url = f"{self.server_url}/parse"
            
            payload = {
                "url": url,
            }
            
            if selector:
                payload["selector"] = selector
                
            payload["extract_text"] = extract_text
                
            async with get_http_client(timeout=self.timeout) as client:
                response = await client.post(parse_url, json=payload)
                
                if response.status_code == 200:
                    result = response.json()
                    return result
                else:
                    logger.error(f"MCP Parse error: {response.status_code} - {response.text}")
                    return None
                    
        except Exception as e:
            logger.error(f"MCP Parse request error: {e}")
            return None
    
    async def fetch_telegram_channel_web(self, channel: str) -> Optional[List[Dict[str, Any]]]:
        """
        Парсит публичный Telegram канал через веб-интерфейс
        
        Args:
            channel: Имя канала (без @)
            
        Returns:
            Список сообщений
        """
        if not self.enabled:
            return None
            
        try:
            # URL публичного Telegram канала
            url = f"https://t.me/s/{channel}"
            
            # Парсим страницу
            result = await self.parse_html(
                url,
                selector=".tgme_widget_message",
                extract_text=True
            )
            
            if not result:
                return None
                
            messages = []
            elements = result.get("elements", [])
            
            for elem in elements:
                text = elem.get("text", "")
                if not text:
                    continue
                    
                # Извлекаем метаданные
                message_id = elem.get("data-post", "").split("/")[-1] if elem.get("data-post") else None
                timestamp = elem.get("data-time")
                
                messages.append({
                    "text": text,
                    "message_id": message_id,
                    "timestamp": timestamp,
                    "channel": channel,
                    "source": "telegram_web",
                })
                
            return messages
            
        except Exception as e:
            logger.error(f"Error fetching Telegram channel {channel}: {e}")
            return None
    
    async def fetch_vk_group_web(self, group_id: str) -> Optional[List[Dict[str, Any]]]:
        """
        Парсит публичную VK группу через веб-интерфейс
        
        Args:
            group_id: ID или screen_name группы
            
        Returns:
            Список постов
        """
        if not self.enabled:
            return None
            
        try:
            # URL публичной VK группы
            if group_id.startswith("-") or group_id.isdigit():
                url = f"https://vk.com/club{group_id.lstrip('-')}"
            else:
                url = f"https://vk.com/{group_id}"
                
            # Парсим страницу
            result = await self.parse_html(
                url,
                selector=".wall_item",
                extract_text=True
            )
            
            if not result:
                return None
                
            posts = []
            elements = result.get("elements", [])
            
            for elem in elements:
                text = elem.get("text", "")
                if not text or len(text.strip()) < 30:
                    continue
                    
                # Извлекаем метаданные
                post_id = elem.get("data-post-id")
                timestamp = elem.get("data-time")
                
                posts.append({
                    "text": text,
                    "post_id": post_id,
                    "timestamp": timestamp,
                    "group_id": group_id,
                    "source": "vk_web",
                })
                
            return posts
            
        except Exception as e:
            logger.error(f"Error fetching VK group {group_id}: {e}")
            return None
    
    async def check_health(self) -> bool:
        """Проверяет доступность MCP Fetch Server"""
        try:
            health_url = f"{self.server_url}/health"
            async with get_http_client(timeout=5.0) as client:
                response = await client.get(health_url)
                return response.status_code == 200
        except Exception as e:
            logger.debug(f"MCP Fetch Server health check failed: {e}")
            return False


# Глобальный экземпляр сервиса
_mcp_fetch_service: Optional[MCPFetchService] = None


def get_mcp_fetch_service() -> MCPFetchService:
    """Получить глобальный экземпляр MCP Fetch Service"""
    global _mcp_fetch_service
    if _mcp_fetch_service is None:
        _mcp_fetch_service = MCPFetchService()
    return _mcp_fetch_service


async def fetch_with_fallback(
    url: str,
    use_mcp: bool = True,
    fallback_to_direct: bool = True,
) -> Optional[Dict[str, Any]]:
    """
    Выполняет запрос с fallback: сначала через MCP, затем напрямую
    
    Args:
        url: URL для запроса
        use_mcp: Использовать ли MCP Fetch Server
        fallback_to_direct: Использовать ли прямой запрос при ошибке MCP
        
    Returns:
        Результат запроса
    """
    if use_mcp and MCP_FETCH_ENABLED:
        service = get_mcp_fetch_service()
        result = await service.fetch_url(url)
        if result:
            return result
    
    if fallback_to_direct:
        try:
            async with get_http_client() as client:
                response = await client.get(url)
                return {
                    "status": response.status_code,
                    "headers": dict(response.headers),
                    "body": response.text,
                    "text": response.text,
                }
        except Exception as e:
            logger.error(f"Direct fetch error: {e}")
            return None
    
    return None
