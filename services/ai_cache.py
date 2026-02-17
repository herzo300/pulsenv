# services/ai_cache.py
"""
Кэширование результатов AI анализа для снижения количества запросов к API
Использует in-memory кэш с TTL и хеширование текста для ключей
"""

import hashlib
import time
import logging
from typing import Dict, Any, Optional
from collections import OrderedDict

logger = logging.getLogger(__name__)

# Глобальный кэш: {hash: (result, timestamp)}
_cache: Dict[str, tuple] = {}
_cache_max_size = 1000  # Максимальное количество записей
_cache_ttl = 3600 * 24  # TTL: 24 часа в секундах


def _hash_text(text: str, model: str = "") -> str:
    """Создает хеш ключ для текста и модели"""
    content = f"{model}:{text[:500]}"  # Используем первые 500 символов для хеша
    return hashlib.sha256(content.encode('utf-8')).hexdigest()


def _hash_image(image_b64: str, caption: str = "", model: str = "") -> str:
    """Создает хеш ключ для изображения"""
    # Используем первые 100 символов base64 и caption
    content = f"{model}:{image_b64[:100]}:{caption[:200]}"
    return hashlib.sha256(content.encode('utf-8')).hexdigest()


def get_cached_text(text: str, model: str = "") -> Optional[Dict[str, Any]]:
    """
    Получить закэшированный результат анализа текста
    
    Args:
        text: Текст для анализа
        model: Название модели (для разделения кэшей разных моделей)
    
    Returns:
        Результат анализа или None если не найден/истек
    """
    cache_key = _hash_text(text, model)
    
    if cache_key not in _cache:
        return None
    
    result, timestamp = _cache[cache_key]
    
    # Проверяем TTL
    if time.time() - timestamp > _cache_ttl:
        del _cache[cache_key]
        logger.debug(f"Cache expired for key: {cache_key[:16]}...")
        return None
    
    logger.debug(f"Cache hit for text analysis (model: {model})")
    return result.copy() if result else None


def set_cached_text(text: str, result: Dict[str, Any], model: str = ""):
    """
    Сохранить результат анализа текста в кэш
    
    Args:
        text: Текст который анализировался
        result: Результат анализа
        model: Название модели
    """
    cache_key = _hash_text(text, model)
    
    # Ограничиваем размер кэша (FIFO)
    if len(_cache) >= _cache_max_size:
        # Удаляем самую старую запись
        oldest_key = min(_cache.keys(), key=lambda k: _cache[k][1])
        del _cache[oldest_key]
        logger.debug(f"Cache full, removed oldest entry")
    
    _cache[cache_key] = (result.copy(), time.time())
    logger.debug(f"Cached text analysis result (model: {model}, cache size: {len(_cache)})")


def get_cached_image(image_b64: str, caption: str = "", model: str = "") -> Optional[Dict[str, Any]]:
    """
    Получить закэшированный результат анализа изображения
    
    Args:
        image_b64: Base64 изображения
        caption: Подпись к изображению
        model: Название модели
    
    Returns:
        Результат анализа или None если не найден/истек
    """
    cache_key = _hash_image(image_b64, caption, model)
    
    if cache_key not in _cache:
        return None
    
    result, timestamp = _cache[cache_key]
    
    # Проверяем TTL
    if time.time() - timestamp > _cache_ttl:
        del _cache[cache_key]
        logger.debug(f"Cache expired for image key: {cache_key[:16]}...")
        return None
    
    logger.debug(f"Cache hit for image analysis (model: {model})")
    return result.copy() if result else None


def set_cached_image(image_b64: str, result: Dict[str, Any], caption: str = "", model: str = ""):
    """
    Сохранить результат анализа изображения в кэш
    
    Args:
        image_b64: Base64 изображения
        result: Результат анализа
        caption: Подпись к изображению
        model: Название модели
    """
    cache_key = _hash_image(image_b64, caption, model)
    
    # Ограничиваем размер кэша (FIFO)
    if len(_cache) >= _cache_max_size:
        # Удаляем самую старую запись
        oldest_key = min(_cache.keys(), key=lambda k: _cache[k][1])
        del _cache[oldest_key]
        logger.debug(f"Cache full, removed oldest entry")
    
    _cache[cache_key] = (result.copy(), time.time())
    logger.debug(f"Cached image analysis result (model: {model}, cache size: {len(_cache)})")


def clear_cache():
    """Очистить весь кэш"""
    global _cache
    size = len(_cache)
    _cache.clear()
    logger.info(f"Cache cleared ({size} entries removed)")


def get_cache_stats() -> Dict[str, Any]:
    """Получить статистику кэша"""
    now = time.time()
    valid_entries = sum(1 for _, (_, ts) in _cache.items() if now - ts <= _cache_ttl)
    expired_entries = len(_cache) - valid_entries
    
    return {
        "total": len(_cache),
        "valid": valid_entries,
        "expired": expired_entries,
        "max_size": _cache_max_size,
        "ttl_hours": _cache_ttl / 3600,
    }


def cleanup_expired():
    """Удалить истекшие записи из кэша"""
    now = time.time()
    expired_keys = [
        key for key, (_, timestamp) in _cache.items()
        if now - timestamp > _cache_ttl
    ]
    
    for key in expired_keys:
        del _cache[key]
    
    if expired_keys:
        logger.debug(f"Cleaned up {len(expired_keys)} expired cache entries")
    
    return len(expired_keys)
