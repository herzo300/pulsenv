# services/nvd_service.py
"""Сервис для работы с API data.n-vartovsk.ru (8603032896-docagtext)"""

import httpx
from typing import Optional, Dict, Any, List
from datetime import datetime
import asyncio

_client: Optional[httpx.AsyncClient] = None
_BASE_URL = "https://data.n-vartovsk.ru/api/v1/8603032896-docagtext"

# Кэш для ответов API (15 минут)
_response_cache: Dict[str, tuple] = {}


def get_client():
    """Singleton HTTP клиент для API запросов"""
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            base_url=_BASE_URL,
            timeout=30.0,
            headers={
                "User-Agent": "Soobshio/1.0",
                "Accept": "application/json",
            },
        )
    return _client


async def get_passport() -> Optional[Dict[str, Any]]:
    """
    Получить паспорт набора открытых данных
    Документация: https://data.n-vartovsk.ru/docs
    """
    try:
        client = get_client()
        response = await client.get(f"{_BASE_URL}/passport")
        response.raise_for_status()
        data = response.json()
        
        return {
            "success": True,
            "data": {
                "identifier": data.get("identifier"),
                "title": data.get("title"),
                "description": data.get("description"),
                "keywords": data.get("keywords", []),
                "publisher": data.get("publisher"),
                "created": data.get("created"),
                "modified": data.get("modified"),
                "source": data.get("source"),
            },
            "fields": data.get("fields", []),
            "examples": data.get("examples", []),
        }
    except httpx.HTTPStatusError as e:
        return {
            "success": False,
            "error": f"HTTP {e.response.status_code}",
            "details": str(e),
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


async def get_structure() -> Optional[Dict[str, Any]]:
    """
    Получить структуру набора открытых данных
    """
    try:
        client = get_client()
        response = await client.get(f"{_BASE_URL}/structure")
        response.raise_for_status()
        data = response.json()
        
        return {
            "success": True,
            "data": {
                "tables": data.get("tables", []),
                "fields": data.get("fields", []),
                "relationships": data.get("relationships", []),
            },
        }
    except httpx.HTTPStatusError as e:
        return {
            "success": False,
            "error": f"HTTP {e.response.status_code}",
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


async def get_data(params: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, Any]]:
    """
    Получить данные из набора открытых данных
    params: словарь параметров запроса
    Пример: {"limit": 10, "offset": 0, "format": "json"}
    """
    try:
        client = get_client()
        response = await client.get(
            f"{_BASE_URL}/data",
            params=params
        )
        response.raise_for_status()
        data = response.json()
        
        return {
            "success": True,
            "data": data,
            "count": len(data) if isinstance(data, list) else 0,
        }
    except httpx.HTTPStatusError as e:
        return {
            "success": False,
            "error": f"HTTP {e.response.status_code}",
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


async def search_data(
    query: str,
    category: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
) -> Optional[Dict[str, Any]]:
    """
    Поиск по данным
    """
    params = {
        "search": query,
        "limit": limit,
        "offset": offset,
    }
    if category:
        params["category"] = category
    
    return await get_data(params=params)


async def get_statistics() -> Optional[Dict[str, Any]]:
    """
    Получить статистику по датасетам
    """
    try:
        client = get_client()
        response = await client.get(f"{_BASE_URL}/statistics")
        response.raise_for_status()
        data = response.json()
        
        return {
            "success": True,
            "statistics": {
                "total_records": data.get("total_records", 0),
                "total_datasets": data.get("total_datasets", 0),
                "last_updated": data.get("last_updated"),
                "size_mb": data.get("size_mb", 0),
                "formats": data.get("formats", []),
            },
        }
    except httpx.HTTPStatusError as e:
        return {
            "success": False,
            "error": f"HTTP {e.response.status_code}",
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


async def get_datasets_list(
    limit: int = 50,
    offset: int = 0,
) -> Optional[Dict[str, Any]]:
    """
    Получить список всех датасетов
    """
    return await get_data(params={"limit": limit, "offset": offset})


async def get_dataset_details(dataset_id: str) -> Optional[Dict[str, Any]]:
    """
    Получить детали конкретного датасета
    """
    try:
        client = get_client()
        response = await client.get(f"{_BASE_URL}/datasets/{dataset_id}")
        response.raise_for_status()
        data = response.json()
        
        return {
            "success": True,
            "dataset": {
                "id": data.get("id"),
                "title": data.get("title"),
                "description": data.get("description"),
                "category": data.get("category"),
                "created": data.get("created"),
                "modified": data.get("modified"),
                "size_mb": data.get("size_mb"),
                "records_count": data.get("records_count"),
                "format": data.get("format"),
                "download_url": data.get("download_url"),
            },
        }
    except httpx.HTTPStatusError as e:
        return {
            "success": False,
            "error": f"HTTP {e.response.status_code}",
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


# Для обратной совместимости
async def get_nvd_info() -> Dict[str, Any]:
    """
    Получить информацию о датасете NVD
    """
    return await get_passport()


async def get_vulnerabilities(limit: int = 20) -> Dict[str, Any]:
    """
    Получить список уязвимостей из NVD
    """
    return await get_data(params={"limit": limit})


def parse_nvd_response(response: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    Парсинг ответа от NVD API
    """
    if response.get("success"):
        data = response.get("data", {})
        if isinstance(data, list):
            return data
        elif isinstance(data, dict):
            return [data]
    return []


async def close_client():
    """Закрыть HTTP клиент"""
    global _client
    if _client:
        await _client.aclose()
        _client = None


__all__ = [
    'get_passport',
    'get_structure',
    'get_data',
    'search_data',
    'get_statistics',
    'get_datasets_list',
    'get_dataset_details',
    'get_nvd_info',
    'get_vulnerabilities',
    'parse_nvd_response',
    'close_client',
]
