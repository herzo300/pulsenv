# services/realtime_guard.py
"""
RealtimeGuard — фильтрация старых сообщений и дедупликация.
Гарантирует обработку только новых сообщений, поступивших после запуска системы.
"""

import logging
from collections import OrderedDict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional, Tuple

logger = logging.getLogger(__name__)


@dataclass
class GuardStats:
    """Статистика фильтрации"""
    skipped_old: int = 0
    skipped_duplicate: int = 0
    processed_count: int = 0


class RealtimeGuard:
    """
    Защита от обработки старых и дублирующихся сообщений.
    
    - Фильтрация по таймстемпу: пропускает только сообщения >= время запуска
    - Дедупликация по (source, message_id): не обрабатывает одно сообщение дважды
    - FIFO-очистка: при превышении max_size удаляет старейшие записи
    """

    def __init__(self, max_size: int = 10000, trim_size: int = 5000):
        self._startup_time: datetime = datetime.now(timezone.utc)
        self._processed_ids: OrderedDict = OrderedDict()
        self._max_size = max_size
        self._trim_size = trim_size
        self._stats = GuardStats()

    def is_new_message(self, timestamp: Optional[datetime]) -> bool:
        """
        Возвращает True если таймстемп >= время запуска.
        Если timestamp is None — считает сообщение новым (warning в лог).
        """
        if timestamp is None:
            logger.warning("⚠️ Сообщение без таймстемпа — считаем новым")
            return True

        # Приводим к aware UTC если naive
        ts = timestamp
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)

        startup = self._startup_time
        if startup.tzinfo is None:
            startup = startup.replace(tzinfo=timezone.utc)

        if ts < startup:
            self._stats.skipped_old += 1
            return False
        return True

    def is_duplicate(self, source: str, message_id: int) -> bool:
        """Возвращает True если сообщение уже обработано."""
        key: Tuple[str, int] = (source, message_id)
        if key in self._processed_ids:
            self._stats.skipped_duplicate += 1
            return True
        return False

    def mark_processed(self, source: str, message_id: int) -> None:
        """Добавляет ID в множество обработанных, при необходимости очищает."""
        key: Tuple[str, int] = (source, message_id)
        self._processed_ids[key] = datetime.now(timezone.utc)
        self._stats.processed_count += 1

        if len(self._processed_ids) > self._max_size:
            # FIFO: удаляем старейшие, оставляем trim_size
            to_remove = len(self._processed_ids) - self._trim_size
            for _ in range(to_remove):
                self._processed_ids.popitem(last=False)
            logger.info(f"🧹 Очистка множества обработанных: {self._max_size} → {len(self._processed_ids)}")

    @property
    def startup_time(self) -> datetime:
        """Время запуска (UTC)"""
        return self._startup_time

    @property
    def stats(self) -> GuardStats:
        """Статистика фильтрации"""
        return self._stats
