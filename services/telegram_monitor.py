# services/telegram_monitor.py
"""Telegram channel monitoring with automatic complaint creation."""

import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

from telethon import TelegramClient, events, types

from .cache_service import get_categories_cached


try:
    from .mcp_fetch_service import get_mcp_fetch_service
    MCP_FETCH_AVAILABLE = True
except ImportError:
    MCP_FETCH_AVAILABLE = False

try:
    from .complaint_service import ComplaintService  # type: ignore
except ImportError:
    ComplaintService = None  # type: ignore

logger = logging.getLogger(__name__)


class TelegramMonitor:
    """Класс для мониторинга и парсинга Telegram каналов"""
    
    def __init__(
        self,
        api_id: int,
        api_hash: str,
        phone: str,
        channels: List[str],
        bot_token: Optional[str] = None,
        db: Optional[Any] = None,
    ):
        self.api_id = api_id
        self.api_hash = api_hash
        self.phone = phone
        self.channels = channels
        self.bot_token = bot_token
        self.client: Optional[TelegramClient] = None
        self.is_connected = False
        self.monitored_messages: List[Dict[str, Any]] = []
        self.complaint_service: Optional[Any] = None
        self.statistics = {
            "total_parsed": 0,
            "by_category": {},
            "by_channel": {},
            "created_complaints": 0,
            "vulnerabilities_found": 0,
        }
    
    async def start(self):
        """Start monitoring channels."""
        if ComplaintService is not None:
            self.complaint_service = ComplaintService()

        session_name = "soobshio_monitor"
        self.client = TelegramClient(
            session_name,
            self.api_id,
            self.api_hash,
        )

        await self.client.start(phone=self.phone)

        # Register event handler for new messages
        @self.client.on(events.NewMessage)
        async def on_new_message(event):
            await self.handle_new_message(event)

        self.is_connected = True
        logger.info("Connected to %d channels", len(self.channels))
    
    async def stop(self):
        """Stop monitoring."""
        if self.client:
            await self.client.disconnect()
            self.is_connected = False
            logger.info("Telegram monitor stopped")
    
    async def join_channels(self):
        """Join monitored channels."""
        for channel in self.channels:
            try:
                entity = await self.client.get_entity(channel)
                if entity:
                    from telethon.tl.functions.channels import JoinChannelRequest
                    await self.client(JoinChannelRequest(entity))
                    logger.info("Joined channel: %s", channel)
            except Exception as e:
                logger.warning("Error joining %s: %s", channel, e)
                # Fallback to web scraping via MCP if available
                if MCP_FETCH_AVAILABLE:
                    try:
                        service = get_mcp_fetch_service()
                        channel_name = channel.lstrip("@")
                        web_messages = await service.fetch_telegram_channel_web(channel_name)
                        if web_messages:
                            logger.info("Got %d messages via MCP web for %s", len(web_messages), channel)
                    except Exception as web_error:
                        logger.debug("MCP web scraping failed: %s", web_error)
    
    async def get_chat_id(self, channel: str) -> Optional[int]:
        """Get chat ID by channel name."""
        try:
            entity = await self.client.get_entity(channel)
            if entity and hasattr(entity, "id"):
                return entity.id
        except Exception as e:
            logger.warning("Error getting chat ID for %s: %s", channel, e)
        return None
    
    async def handle_new_message(self, event):
        """Processes a new message event and creates complaints if relevant."""
        if not event.message or not event.message.text:
            return
            
        try:
            # Parse message
            parsed = await self.parse_message(event.message)
            if not parsed:
                return
                
            # If it's a valid category, we treat it as a potential complaint
            if parsed.get("category") != "Прочее":
                 # Import here to avoid circular dependencies
                 from services.supabase_service import push_complaint, upload_image
                 
                 # Handle photos if present
                 photos = []
                 if event.message.media:
                      from io import BytesIO
                      import time
                      buffer = BytesIO()
                      await self.client.download_media(event.message.media, buffer)
                      
                      filename = f"tg_{int(time.time())}_{event.message.id}.jpg"
                      url = await upload_image(buffer.getvalue(), filename)
                      if url:
                          photos.append(url)
                 
                 # Push to Supabase
                 await push_complaint({
                     "title": parsed.get("summary", parsed.get("text", ""))[:150],
                     "description": parsed.get("text", ""),
                     "category": parsed.get("category", "Прочее"),
                     "address": parsed.get("address"),
                     "images": photos,
                     "source": f"telegram:{parsed.get('channel', 'channel')}",
                     "telegram_message_id": str(event.message.id),
                     "telegram_channel": parsed.get("channel", ""),
                     "created_at": datetime.utcnow().isoformat()
                 })
                 self.statistics["created_complaints"] += 1
                 logger.info("✅ Жалоба создана из Telegram [%s]: %s", parsed.get("channel"), parsed.get("category"))
                 
        except Exception as e:
            logger.error("Error in Telegram monitor handle_new_message: %s", e)
    
    async def parse_message(self, message: types.Message) -> Optional[Dict[str, Any]]:
        """
        Парсинг сообщения для извлечения данных
        Извлекает:
        - Текст жалобы/проблемы
        - Категория
        - Адрес/координаты
        - Фотографии
        - Уязвимости (CVE)
        """
        if not message.text:
            return None
        
        text = message.text.lower()
        result = {
            "timestamp": message.date.isoformat() if message.date else None,
            "source": "telegram",
            "channel": getattr(message.chat, 'username', ''),
            "message_id": message.id,
            "text": message.text,
            "has_media": bool(message.media),
        }
        
        # Определение категории по ключевым словам
        categories = get_categories_cached().get("categories", [])
        category_keywords = {
            "Дороги": ["яма", "ямы", "дорога", "светофор", "дорожный"],
            "Освещение": ["нет света", "свет", "лампа", "фонарь", "освещение", "горит", "отключили"],
            "ЖКХ": ["мусор", "свалка", "контейнер", "уборка", "жкх", "вода", "трубы", "канализация"],
            "Транспорт": ["автобус", "маршрут", "трамвай", "остановка", "парковка", "метро"],
            "Зеленые зоны": ["парк", "сквер", "аллея", "дерево", "газон"],
            "Парки": ["парковка", "парк", "место", "машина", "авто"],
            "Образование": ["школа", "детский", "детсад", "учебник", "учеба"],
            "Медицина": ["больница", "аптека", "поликлиника", "врач", "медицинский", "лечебница"],
            "Безопасность": ["камера", "охрана", "пожар", "пожарный", "безопасность"],
        }
        
        detected_category = None
        for category, keywords in category_keywords.items():
            if any(keyword in text for keyword in keywords):
                detected_category = category
                break
        
        if detected_category:
            result["category"] = detected_category
            result["category_confidence"] = "high"
        else:
            result["category"] = "Прочее"
            result["category_confidence"] = "low"
        
        # Извлечение фотографий
        result["photos"] = []
        if message.media:
            result["has_media"] = True
            if hasattr(message.media, 'photo'):
                result["photos"].append({
                    "type": "photo",
                    "caption": message.media.caption if hasattr(message.media, 'caption') else None,
                })
        
        # Vulnerability check removed
            
        return result
    
    async def parse_text(self, text: str, message_id: int = 0, channel: str = "") -> Dict[str, Any]:
        """Парсинг только по тексту (без объекта Message). Возвращает структуру как parse_message."""
        if not text or not text.strip():
            return {"category": "Прочее", "category_confidence": "low", "text": "", "message_id": message_id}
        text_lower = text.lower()
        result = {
            "timestamp": datetime.utcnow().isoformat(),
            "source": "telegram",
            "channel": channel,
            "message_id": message_id,
            "text": text,
            "has_media": False,
        }
        category_keywords = {
            "Дороги": ["яма", "ямы", "дорога", "светофор", "дорожный"],
            "Освещение": ["нет света", "свет", "лампа", "фонарь", "освещение", "горит", "отключили"],
            "ЖКХ": ["мусор", "свалка", "контейнер", "уборка", "жкх", "вода", "трубы", "канализация"],
            "Транспорт": ["автобус", "маршрут", "трамвай", "остановка", "парковка", "метро"],
        }
        detected = None
        for category, keywords in category_keywords.items():
            if any(kw in text_lower for kw in keywords):
                detected = category
                break
        result["category"] = detected or "Прочее"
        result["category_confidence"] = "high" if detected else "low"
        result["photos"] = []
        result["vulnerabilities"] = []
        result["has_vulnerabilities"] = False
        return result

    async def post_message_to_channel(self, channel: str, text: str, photo: Optional[str] = None) -> bool:
        """
        Отправить сообщение в канал (опционально создать жалобу в БД через ComplaintService).
        """
        if not self.client or not self.is_connected:
            print("❌ Telegram клиент не подключен")
            return False

        try:
            parsed = await self.parse_text(text, message_id=0, channel=channel)

            if self.complaint_service is not None and parsed["category"] != "Прочее" and parsed["category_confidence"] == "high":
                try:
                    if getattr(self.complaint_service, "db", None):
                        complaint = await self.complaint_service.create_complaint(
                            db=self.complaint_service.db,
                            title=parsed["text"][:100] if len(parsed["text"]) > 100 else parsed["text"],
                            description=parsed["text"],
                            category=parsed["category"],
                            status="open",
                            source="telegram_monitoring",
                            telegram_message_id=str(parsed["message_id"]),
                            telegram_channel=channel,
                        )
                        if complaint:
                            self.statistics["created_complaints"] += 1
                            self.statistics["total_parsed"] += 1
                            logger.info("Complaint created from %s: %s", channel, parsed["text"][:50])
                except Exception as e:
                    logger.error("Error creating complaint: %s", e)

            if photo:
                await self.client.send_message(channel, text, file=photo)
            else:
                await self.client.send_message(channel, text)

            self.statistics["total_parsed"] += 1
            logger.info("Message sent to %s: %s", channel, text[:50])
            return True
        except Exception as e:
            logger.error("Error sending to %s: %s", channel, e)
            return False
    

    
    def get_statistics(self) -> Dict[str, Any]:
        """
        Получить статистику по спарсенным сообщениям
        """
        if not self.monitored_messages:
            return {
                "total_messages": 0,
                "by_category": {},
                "by_channel": {},
                "recent": [],
                "created_complaints": self.statistics["created_complaints"],
                "vulnerabilities_found": self.statistics["vulnerabilities_found"],
            }
        
        by_category: Dict[str, int] = {}
        by_channel: Dict[str, int] = {}
        
        for msg in self.monitored_messages:
            category = msg.get("category", "Прочее")
            channel = msg.get("channel", "unknown")
            
            by_category[category] = by_category.get(category, 0) + 1
            by_channel[channel] = by_channel.get(channel, 0) + 1
        
        return {
            "total_messages": len(self.monitored_messages),
            "by_category": by_category,
            "by_channel": by_channel,
            "recent": self.monitored_messages[-10:] if self.monitored_messages else [],
            "created_complaints": self.statistics["created_complaints"],
            "vulnerabilities_found": self.statistics["vulnerabilities_found"],
        }
    
    def get_filtered_messages(
        self,
        category: Optional[str] = None,
        limit: int = 100,
    ) -> List[Dict[str, Any]]:
        """Получить отфильтрованные сообщения"""
        filtered = self.monitored_messages
        
        if category:
            filtered = [msg for msg in filtered if msg.get("category") == category]
        
        return filtered[:limit] if limit else filtered


def set_database(db: Any):
    """Установить соединение с БД для жалоб"""
    from services.telegram_monitor import TelegramMonitor
    TelegramMonitor.db = db


async def start_telegram_monitoring(
    api_id: int,
    api_hash: str,
    phone: str,
    channels: List[str],
    bot_token: Optional[str] = None,
    db: Optional[Any] = None,
):
    """
    Запустить мониторинг Telegram каналов.
    Фабричная функция для создания и запуска TelegramMonitor.
    
    Returns:
        TelegramMonitor: Запущенный экземпляр монитора
    """
    monitor = TelegramMonitor(
        api_id=api_id,
        api_hash=api_hash,
        phone=phone,
        channels=channels,
        bot_token=bot_token,
        db=db,
    )
    await monitor.start()
    return monitor
