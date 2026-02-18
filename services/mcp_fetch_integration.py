# services/mcp_fetch_integration.py
"""
Интеграция MCP Fetch Server в систему мониторинга
Предоставляет единый интерфейс для парсинга через MCP и fallback на стандартные методы
"""

import asyncio
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime

from .mcp_fetch_service import get_mcp_fetch_service, MCP_FETCH_ENABLED

logger = logging.getLogger(__name__)


async def fetch_telegram_channel_messages(
    channel: str,
    use_mcp: bool = True,
    limit: int = 20,
) -> List[Dict[str, Any]]:
    """
    Получает сообщения из Telegram канала через MCP или стандартный метод
    
    Args:
        channel: Имя канала (с @ или без)
        use_mcp: Использовать ли MCP Fetch Server
        limit: Максимальное количество сообщений
        
    Returns:
        Список сообщений
    """
    channel_clean = channel.lstrip("@")
    messages = []
    
    if use_mcp and MCP_FETCH_ENABLED:
        try:
            service = get_mcp_fetch_service()
            web_messages = await service.fetch_telegram_channel_web(channel_clean)
            
            if web_messages:
                logger.info(f"✅ Получено {len(web_messages)} сообщений через MCP для {channel}")
                messages.extend(web_messages[:limit])
                return messages
        except Exception as e:
            logger.debug(f"MCP fetch для Telegram {channel} не удался: {e}")
    
    # Fallback на стандартный метод (через Telethon)
    # Это должно быть реализовано в telegram_monitor.py
    return messages


async def fetch_vk_group_posts(
    group_id: str,
    use_mcp: bool = True,
    count: int = 10,
) -> List[Dict[str, Any]]:
    """
    Получает посты из VK группы через MCP или стандартный метод
    
    Args:
        group_id: ID или screen_name группы
        use_mcp: Использовать ли MCP Fetch Server
        count: Количество постов
        
    Returns:
        Список постов
    """
    posts = []
    
    if use_mcp and MCP_FETCH_ENABLED:
        try:
            service = get_mcp_fetch_service()
            web_posts = await service.fetch_vk_group_web(group_id)
            
            if web_posts:
                logger.info(f"✅ Получено {len(web_posts)} постов через MCP для группы {group_id}")
                posts.extend(web_posts[:count])
                return posts
        except Exception as e:
            logger.debug(f"MCP fetch для VK {group_id} не удался: {e}")
    
    # Fallback на стандартный метод (через VK API)
    # Это должно быть реализовано в vk_monitor_service.py
    return posts


async def check_mcp_availability() -> Dict[str, Any]:
    """
    Проверяет доступность MCP Fetch Server
    
    Returns:
        Dict с информацией о статусе
    """
    if not MCP_FETCH_ENABLED:
        return {
            "enabled": False,
            "available": False,
            "message": "MCP Fetch Server отключен в конфигурации",
        }
    
    try:
        service = get_mcp_fetch_service()
        is_available = await service.check_health()
        
        return {
            "enabled": True,
            "available": is_available,
            "server_url": service.server_url,
            "message": "MCP Fetch Server доступен" if is_available else "MCP Fetch Server недоступен",
        }
    except Exception as e:
        return {
            "enabled": True,
            "available": False,
            "error": str(e),
            "message": f"Ошибка проверки MCP Fetch Server: {e}",
        }
