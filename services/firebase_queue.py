# services/firebase_queue.py
"""
Очередь для отложенной публикации в Firebase
Если Firebase недоступен, жалобы сохраняются в очередь для повторной отправки
"""

import asyncio
import logging
from typing import Dict, Any, Optional
from datetime import datetime
from collections import deque
from services.firebase_service import push_complaint

logger = logging.getLogger(__name__)

# Очередь для отложенной отправки
_firebase_queue: deque = deque()
_max_queue_size = 1000
_processing = False


def add_to_queue(complaint: Dict[str, Any]):
    """
    Добавить жалобу в очередь для отложенной отправки
    
    Args:
        complaint: Данные жалобы для отправки в Firebase
    """
    if len(_firebase_queue) >= _max_queue_size:
        # Удаляем самую старую запись
        _firebase_queue.popleft()
        logger.warning("Firebase queue full, removed oldest entry")
    
    complaint_with_timestamp = {
        **complaint,
        "_queued_at": datetime.utcnow().isoformat(),
        "_retry_count": 0,
    }
    _firebase_queue.append(complaint_with_timestamp)
    logger.info(f"Added complaint to Firebase queue (queue size: {len(_firebase_queue)})")


async def process_queue():
    """Обработать очередь Firebase (отправить все накопленные жалобы)"""
    global _processing
    
    if _processing:
        logger.debug("Firebase queue processing already in progress")
        return
    
    if not _firebase_queue:
        return
    
    _processing = True
    logger.info(f"Processing Firebase queue ({len(_firebase_queue)} items)")
    
    processed = 0
    failed = 0
    
    while _firebase_queue:
        complaint = _firebase_queue.popleft()
        retry_count = complaint.get("_retry_count", 0)
        
        # Удаляем служебные поля перед отправкой
        complaint_clean = {k: v for k, v in complaint.items() if not k.startswith("_")}
        
        try:
            result = await push_complaint(complaint_clean)
            if result:
                processed += 1
                logger.debug(f"Successfully sent queued complaint to Firebase")
            else:
                # Если отправка не удалась, возвращаем в очередь (но не более 3 попыток)
                if retry_count < 3:
                    complaint["_retry_count"] = retry_count + 1
                    _firebase_queue.append(complaint)
                    failed += 1
                    logger.warning(f"Failed to send queued complaint, retry {retry_count + 1}/3")
                else:
                    logger.error(f"Failed to send queued complaint after 3 retries, dropping")
        except Exception as e:
            logger.error(f"Error processing queued complaint: {e}")
            if retry_count < 3:
                complaint["_retry_count"] = retry_count + 1
                _firebase_queue.append(complaint)
                failed += 1
            else:
                logger.error(f"Failed after 3 retries, dropping complaint")
        
        # Небольшая задержка между отправками
        await asyncio.sleep(0.5)
    
    _processing = False
    logger.info(f"Firebase queue processed: {processed} sent, {failed} failed/retried")


def get_queue_stats() -> Dict[str, Any]:
    """Получить статистику очереди"""
    return {
        "size": len(_firebase_queue),
        "max_size": _max_queue_size,
        "processing": _processing,
    }


def clear_queue():
    """Очистить очередь"""
    global _firebase_queue
    size = len(_firebase_queue)
    _firebase_queue.clear()
    logger.info(f"Firebase queue cleared ({size} items removed)")
