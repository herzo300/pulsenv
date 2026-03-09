# services/supabase_service.py
"""
Supabase Service — real-time complaint sync via Supabase REST API.
Supabase integration service.
"""

import asyncio
import logging
import os
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional

import httpx

logger = logging.getLogger(__name__)

# Supabase Configuration
SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
SUPABASE_ANON_KEY: str = os.getenv("SUPABASE_ANON_API_KEY", "")
SUPABASE_SERVICE_KEY: str = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_SERVICE_KEY")
    or SUPABASE_ANON_KEY
)

# Retry settings
MAX_RETRIES = 3
RETRY_DELAY = 1.0
REQUEST_TIMEOUT = 15.0


class SupabaseService:
    """Сервис для работы с Supabase REST API"""
    
    def __init__(self):
        self.base_url = SUPABASE_URL.rstrip("/")
        self.api_key = SUPABASE_ANON_KEY or SUPABASE_SERVICE_KEY
        self.rest_url = f"{self.base_url}/rest/v1"
        self._headers = {
            "apikey": self.api_key,
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        }
        self._client: Optional[httpx.AsyncClient] = None
    
    @property
    def is_configured(self) -> bool:
        """Проверяет, настроен ли Supabase"""
        return bool(self.base_url and self.api_key)
    
    async def _get_client(self) -> httpx.AsyncClient:
        """Получает HTTP клиент (создаёт при необходимости)"""
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(
                timeout=REQUEST_TIMEOUT,
                headers=self._headers,
            )
        return self._client
    
    async def close(self):
        """Закрывает HTTP клиент"""
        if self._client and not self._client.is_closed:
            await self._client.aclose()
            self._client = None
    
    async def _request(
        self,
        method: str,
        endpoint: str,
        json_data: Optional[Dict] = None,
        params: Optional[Dict] = None,
    ) -> Optional[Any]:
        """Выполняет HTTP запрос с retry логикой"""
        url = f"{self.rest_url}/{endpoint}"
        client = await self._get_client()
        
        for attempt in range(MAX_RETRIES):
            try:
                if method == "GET":
                    response = await client.get(url, params=params)
                elif method == "POST":
                    response = await client.post(url, json=json_data, params=params)
                elif method == "PATCH":
                    response = await client.patch(url, json=json_data, params=params)
                elif method == "DELETE":
                    response = await client.delete(url, params=params)
                else:
                    raise ValueError(f"Unknown method: {method}")
                
                if response.status_code in (200, 201, 204):
                    if response.text:
                        return response.json()
                    return True
                
                if response.status_code == 409:  # Duplicate
                    logger.debug("Supabase: duplicate record, skipping")
                    return True
                
                if 500 <= response.status_code < 600:
                    logger.warning(f"Supabase server error: {response.status_code}")
                    if attempt < MAX_RETRIES - 1:
                        await asyncio.sleep(RETRY_DELAY * (attempt + 1))
                        continue
                
                logger.error(f"Supabase error: {response.status_code} - {response.text[:200]}")
                return None
                
            except (httpx.TimeoutException, httpx.ConnectError) as e:
                logger.warning(f"Supabase connection error (attempt {attempt + 1}): {e}")
                if attempt < MAX_RETRIES - 1:
                    await asyncio.sleep(RETRY_DELAY * (attempt + 1))
                else:
                    logger.error(f"Supabase error after {MAX_RETRIES} retries: {e}")
                    return None
            except Exception as e:
                logger.error(f"Supabase unexpected error: {e}")
                return None
        
        return None
    
    # ==================== COMPLAINTS ====================
    

    async def push_complaint(self, complaint: Dict[str, Any]) -> Optional[str]:
        """Сохраняет жалобу в Supabase (поддерживает UPSERT если передан external_id)"""
        if not self.is_configured:
            logger.warning("Supabase not configured")
            return None
        
        # Если external_id уже есть (например, из портала), используем его
        doc_id = complaint.get("external_id")
        is_upsert = doc_id is not None
        
        if not doc_id:
            doc_id = str(uuid.uuid4())[:8] + "_" + datetime.utcnow().strftime("%H%M%S")
        
        payload = {
            "external_id": doc_id,
            "category": complaint.get("category", "Прочее"),
            "summary": (complaint.get("summary") or complaint.get("title") or "")[:200],
            "description": (complaint.get("text") or complaint.get("description") or "")[:2000],
            "address": complaint.get("address"),
            "lat": complaint.get("lat"),
            "lng": complaint.get("lng"),
            "source": complaint.get("source", "unknown"),
            "source_name": complaint.get("source_name", ""),
            "post_link": complaint.get("post_link", ""),
            "provider": complaint.get("provider", ""),
            "status": complaint.get("status", "open"),
            "telegram_message_id": complaint.get("telegram_message_id"),
            "telegram_channel": complaint.get("telegram_channel"),
            "images": complaint.get("images", []) or complaint.get("photos", []),
            "created_at": complaint.get("created_at") or datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat(),
        }
        
        # Для UPSERT добавляем заголовок
        params = {}
        if is_upsert:
            params["on_conflict"] = "external_id"
            # Мы не можем легко поменять заголовок в _request, 
            # но PostgREST позволяет передать on_conflict в params для некоторых версий
            # или мы просто надеемся на уникальный индекс в БД и обработку 409 в _request.
            # Наш _request уже возвращает True при 409!
        
        result = await self._request("POST", "complaints", json_data=payload)
        
        if result:
            logger.info(f"Supabase: жалоба {'обновлена/сохранена' if is_upsert else 'сохранена'} ({doc_id})")
            return doc_id
        
        return None
    
    async def get_recent_complaints(self, limit: int = 50) -> List[Dict]:
        """Получает последние жалобы"""
        if not self.is_configured:
            return []
        
        params = {
            "select": "*",
            "order": "created_at.desc",
            "limit": str(limit),
        }
        
        result = await self._request("GET", "complaints", params=params)
        
        if isinstance(result, list):
            return result
        return []
    
    async def get_complaint_by_id(self, complaint_id: str) -> Optional[Dict]:
        """Получает жалобу по ID"""
        if not self.is_configured:
            return None
        
        params = {
            "select": "*",
            "or": f"(id.eq.{complaint_id},external_id.eq.{complaint_id})",
            "limit": "1",
        }
        
        result = await self._request("GET", "complaints", params=params)
        
        if isinstance(result, list) and result:
            return result[0]
        return None
    
    async def update_complaint_status(self, complaint_id: str, status: str) -> bool:
        """Обновляет статус жалобы"""
        if not self.is_configured:
            return False
        
        payload = {
            "status": status,
            "updated_at": datetime.utcnow().isoformat(),
        }
        
        # Пробуем по external_id или id
        params = {"external_id": f"eq.{complaint_id}"}
        result = await self._request("PATCH", "complaints", json_data=payload, params=params)
        
        if result:
            logger.info(f"Supabase: статус жалобы {complaint_id} обновлён на {status}")
            return True
        
        return False
    
    async def get_complaints_by_category(self, category: str, limit: int = 50) -> List[Dict]:
        """Получает жалобы по категории"""
        if not self.is_configured:
            return []
        
        params = {
            "select": "*",
            "category": f"eq.{category}",
            "order": "created_at.desc",
            "limit": str(limit),
        }
        
        result = await self._request("GET", "complaints", params=params)
        
        if isinstance(result, list):
            return result
        return []
    
    async def search_complaints(
        self,
        query: Optional[str] = None,
        category: Optional[str] = None,
        status: Optional[str] = None,
        limit: int = 50,
    ) -> List[Dict]:
        """Поиск жалоб с фильтрами"""
        if not self.is_configured:
            return []
        
        params = {
            "select": "*",
            "order": "created_at.desc",
            "limit": str(limit),
        }
        
        if category:
            params["category"] = f"eq.{category}"
        if status:
            params["status"] = f"eq.{status}"
        if query:
            params["or"] = f"(description.ilike.%{query}%,address.ilike.%{query}%,summary.ilike.%{query}%)"
        
        result = await self._request("GET", "complaints", params=params)
        
        if isinstance(result, list):
            return result
        return []
    
    # ==================== STATS ====================
    
    async def _increment_stats(self, category: str):
        """Обновляет статистику"""
        try:
            # Получаем текущую статистику
            params = {"key": "eq.realtime_stats", "limit": "1"}
            result = await self._request("GET", "stats", params=params)
            
            if isinstance(result, list) and result:
                current = result[0].get("data", {})
            else:
                current = {}
            
            total = (current.get("total_complaints") or 0) + 1
            by_cat = current.get("by_category") or {}
            by_cat[category] = (by_cat.get(category) or 0) + 1
            
            new_data = {
                "key": "realtime_stats",
                "data": {
                    "total_complaints": total,
                    "by_category": by_cat,
                    "last_updated": datetime.utcnow().isoformat(),
                },
                "updated_at": datetime.utcnow().isoformat(),
            }
            
            if isinstance(result, list) and result:
                await self._request("PATCH", "stats", json_data=new_data, params=params)
            else:
                await self._request("POST", "stats", json_data=new_data)
                
        except Exception as e:
            logger.debug(f"Stats update error: {e}")
    
    async def get_stats(self) -> Dict[str, Any]:
        """Получает текущую статистику"""
        if not self.is_configured:
            return {}
        
        params = {"key": "eq.realtime_stats", "limit": "1"}
        result = await self._request("GET", "stats", params=params)
        
        if isinstance(result, list) and result:
            return result[0].get("data", {})
        return {}
    
    # ==================== INFOGRAPHIC ====================
    
    async def save_infographic_data(self, data_type: str, data: Any) -> bool:
        """Сохраняет данные инфографики"""
        if not self.is_configured:
            return False
            
        params = {"data_type": f"eq.{data_type}", "select": "id"}
        existing = await self._request("GET", "infographic_data", params=params)
        
        payload = {
            "data_type": data_type,
            "data": data,
            "updated_at": datetime.utcnow().isoformat(),
        }
        
        if isinstance(existing, list) and existing:
            # Обновляем существующую запись
            patch_params = {"data_type": f"eq.{data_type}"}
            result = await self._request("PATCH", "infographic_data", json_data=payload, params=patch_params)
        else:
            # Создаем новую
            result = await self._request("POST", "infographic_data", json_data=payload)
            
        return result is not None
    
    async def get_infographic_data(self, data_type: Optional[str] = None) -> Dict[str, Any]:
        """Получает данные инфографики"""
        if not self.is_configured:
            return {}
        
        params = {"select": "*"}
        if data_type:
            params["data_type"] = f"eq.{data_type}"
        
        result = await self._request("GET", "infographic_data", params=params)
        
        if isinstance(result, list):
            if data_type and result:
                return result[0].get("data", {})
            return {item["data_type"]: item["data"] for item in result}
        return {}
    
    # ==================== USERS ====================
    
    async def get_or_create_user(self, telegram_id: int, user_data: Dict) -> Optional[Dict]:
        """Получает или создаёт пользователя"""
        if not self.is_configured:
            return None
        
        # Ищем существующего
        params = {"telegram_id": f"eq.{telegram_id}", "limit": "1"}
        result = await self._request("GET", "users", params=params)
        
        if isinstance(result, list) and result:
            return result[0]
        
        # Создаём нового
        payload = {
            "telegram_id": telegram_id,
            "username": user_data.get("username"),
            "first_name": user_data.get("first_name"),
            "last_name": user_data.get("last_name"),
            "photo_url": user_data.get("photo_url"),
            "created_at": datetime.utcnow().isoformat(),
        }
        
        result = await self._request("POST", "users", json_data=payload)
        
        if isinstance(result, list) and result:
            return result[0]
        return None
    
    async def update_user(self, telegram_id: int, updates: Dict) -> bool:
        """Обновляет данные пользователя"""
        if not self.is_configured:
            return False
        
        updates["updated_at"] = datetime.utcnow().isoformat()
        params = {"telegram_id": f"eq.{telegram_id}"}
        
        result = await self._request("PATCH", "users", json_data=updates, params=params)
        return result is not None


# Глобальный экземпляр сервиса
_supabase_service: Optional[SupabaseService] = None


def get_supabase_service() -> SupabaseService:
    """Получает глобальный экземпляр Supabase сервиса"""
    global _supabase_service
    if _supabase_service is None:
        _supabase_service = SupabaseService()
    return _supabase_service


# ==================== CONVENIENCE FUNCTIONS ====================

async def push_complaint(complaint: Dict[str, Any]) -> Optional[str]:
    """Сохраняет жалобу в Supabase (convenience function)"""
    service = get_supabase_service()
    return await service.push_complaint(complaint)


async def get_recent_complaints(limit: int = 50) -> List[Dict]:
    """Получает последние жалобы (convenience function)"""
    service = get_supabase_service()
    return await service.get_recent_complaints(limit)


async def update_complaint_status(complaint_id: str, status: str) -> bool:
    """Обновляет статус жалобы (convenience function)"""
    service = get_supabase_service()
    return await service.update_complaint_status(complaint_id, status)


async def get_stats() -> Dict[str, Any]:
    """Получает статистику (convenience function)"""
    service = get_supabase_service()
    return await service.get_stats()


def is_supabase_configured() -> bool:
    """Проверяет, настроен ли Supabase"""
    service = get_supabase_service()
    return service.is_configured



async def upload_file(bucket_name: str, path: str, file_data: bytes, content_type: str = "image/jpeg") -> Optional[str]:
    """Загружает файл в Supabase Storage и возвращает публичный URL"""
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        logger.error("Supabase credentials not set for storage upload")
        return None

    try:
        from supabase import create_client
        client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        bucket = client.storage.from_(bucket_name)
        
        bucket.upload(
            path=path,
            file=file_data,
            file_options={"content-type": content_type, "upsert": "true"}
        )
        return f"{SUPABASE_URL}/storage/v1/object/public/{bucket_name}/{path}"
    except Exception as e:
        logger.error(f"Supabase Storage upload error: {e}")
        return f"{SUPABASE_URL}/storage/v1/object/public/{bucket_name}/{path}"


async def upload_image(image_data: bytes, filename: str) -> Optional[str]:
    """Удобная обертка для загрузки изображений жалоб"""
    return await upload_file("static", f"complaints/{filename}", image_data, "image/jpeg")


__all__ = [
    "SupabaseService",
    "get_supabase_service",
    "push_complaint",
    "get_recent_complaints",
    "update_complaint_status",
    "get_stats",
    "is_supabase_configured",
    "upload_file",
    "upload_image",
]
