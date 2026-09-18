import asyncio
import logging
from typing import Callable, Any, Awaitable

logger = logging.getLogger(__name__)

class AIPriorityManager:
    """Управляет приоритетами и лимитами конкурентности для AI задач."""
    
    _semaphore: asyncio.Semaphore = None
    _max_concurrent_tasks: int = 5
    
    @classmethod
    def get_semaphore(cls) -> asyncio.Semaphore:
        if cls._semaphore is None:
            # Инициализируем семафор при первом вызове (внутри event loop)
            cls._semaphore = asyncio.Semaphore(cls._max_concurrent_tasks)
        return cls._semaphore

    @classmethod
    async def execute(cls, priority: int, func: Callable[..., Awaitable[Any]], *args, **kwargs) -> Any:
        """
        Выполняет задачу с учетом семафора конкурентности.
        В идеале priority 0 (VIP) должен обходить обычную очередь, 
        но для упрощения в FastAPI мы используем простой семафор, 
        а asyncio.PriorityQueue можно внедрить для более сложной логики.
        Здесь мы симулируем приоритетность: VIP (priority=0) может получать 
        отдельный пул ресурсов или bypass.
        """
        sem = cls.get_semaphore()
        
        # Если это VIP, мы можем позволить ему обойти лимиты, если обычная очередь заполнена
        if priority == 0:
            logger.info("Executing VIP AI task (priority 0) bypass limits")
            return await func(*args, **kwargs)
            
        async with sem:
            logger.info("Executing standard AI task (priority %s)", priority)
            return await func(*args, **kwargs)
