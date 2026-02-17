# services/rate_limiter.py
"""
Rate limiting для защиты от спама и злоупотреблений
Использует простой sliding window алгоритм
"""

import time
import logging
from typing import Dict, Optional
from collections import defaultdict, deque

logger = logging.getLogger(__name__)

# Хранилище для rate limit данных: {key: deque(timestamps)}
_rate_limits: Dict[str, deque] = defaultdict(lambda: deque())


class RateLimiter:
    """Rate limiter для ограничения частоты запросов"""
    
    def __init__(self, max_requests: int = 10, window_seconds: int = 60):
        """
        Args:
            max_requests: Максимальное количество запросов
            window_seconds: Временное окно в секундах
        """
        self.max_requests = max_requests
        self.window_seconds = window_seconds
    
    def is_allowed(self, key: str) -> bool:
        """
        Проверить, разрешен ли запрос
        
        Args:
            key: Уникальный ключ (например, user_id или ip)
        
        Returns:
            True если запрос разрешен, False если превышен лимит
        """
        now = time.time()
        timestamps = _rate_limits[key]
        
        # Удаляем старые записи вне окна
        while timestamps and now - timestamps[0] > self.window_seconds:
            timestamps.popleft()
        
        # Проверяем лимит
        if len(timestamps) >= self.max_requests:
            logger.warning(f"Rate limit exceeded for key: {key} ({len(timestamps)}/{self.max_requests} in {self.window_seconds}s)")
            return False
        
        # Добавляем текущий запрос
        timestamps.append(now)
        return True
    
    def get_remaining(self, key: str) -> int:
        """Получить количество оставшихся запросов"""
        now = time.time()
        timestamps = _rate_limits[key]
        
        # Удаляем старые записи
        while timestamps and now - timestamps[0] > self.window_seconds:
            timestamps.popleft()
        
        return max(0, self.max_requests - len(timestamps))
    
    def reset(self, key: str):
        """Сбросить счетчик для ключа"""
        if key in _rate_limits:
            _rate_limits[key].clear()


# Импорт настроек из конфигурации
from core.config import RATE_LIMIT_COMPLAINT, RATE_LIMIT_ADMIN, RATE_LIMIT_GENERAL

# Глобальные rate limiters для разных действий
complaint_limiter = RateLimiter(max_requests=RATE_LIMIT_COMPLAINT, window_seconds=60)
admin_limiter = RateLimiter(max_requests=RATE_LIMIT_ADMIN, window_seconds=60)
general_limiter = RateLimiter(max_requests=RATE_LIMIT_GENERAL, window_seconds=60)


def check_rate_limit(user_id: int, action: str = "general") -> bool:
    """
    Проверить rate limit для пользователя и действия
    
    Args:
        user_id: ID пользователя
        action: Тип действия ("complaint", "admin", "general")
    
    Returns:
        True если разрешено, False если превышен лимит
    """
    key = f"{action}:{user_id}"
    
    if action == "complaint":
        return complaint_limiter.is_allowed(key)
    elif action == "admin":
        return admin_limiter.is_allowed(key)
    else:
        return general_limiter.is_allowed(key)


def get_rate_limit_info(user_id: int, action: str = "general") -> Dict[str, any]:
    """Получить информацию о rate limit для пользователя"""
    key = f"{action}:{user_id}"
    
    if action == "complaint":
        limiter = complaint_limiter
    elif action == "admin":
        limiter = admin_limiter
    else:
        limiter = general_limiter
    
    return {
        "remaining": limiter.get_remaining(key),
        "max_requests": limiter.max_requests,
        "window_seconds": limiter.window_seconds,
    }
