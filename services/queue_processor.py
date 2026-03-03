# services/queue_processor.py
"""
Периодическая обработка: очистка кэша AI
"""

import asyncio
import logging
from services.ai_cache import cleanup_expired

logger = logging.getLogger(__name__)

PROCESS_INTERVAL = 300  # Интервал обработки: 5 минут


async def process_queues_periodically():
    """Периодически очищать кэш AI"""
    logger.info("Starting periodic cache cleanup processor")

    while True:
        try:
            # Очистка истекших записей из кэша AI
            expired_count = cleanup_expired()
            if expired_count > 0:
                logger.info(f"Cleaned up {expired_count} expired AI cache entries")

        except Exception as e:
            logger.error(f"Error in queue processor: {e}", exc_info=True)

        # Ждем перед следующей итерацией
        await asyncio.sleep(PROCESS_INTERVAL)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    try:
        asyncio.run(process_queues_periodically())
    except KeyboardInterrupt:
        logger.info("Queue processor stopped")
