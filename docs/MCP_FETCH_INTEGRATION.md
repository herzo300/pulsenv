# Интеграция MCP Fetch Server

## Описание

Интеграция MCP (Model Context Protocol) Fetch Server для парсинга Telegram каналов и VK пабликов через веб-интерфейс. Используется как альтернативный метод получения данных при недоступности официальных API.

## Возможности

1. **Парсинг Telegram каналов** через публичный веб-интерфейс
2. **Парсинг VK групп** через публичный веб-интерфейс
3. **Fallback механизм**: автоматическое переключение на стандартные методы при недоступности MCP
4. **Единый интерфейс** для работы с различными источниками данных

## Установка и настройка

### 1. Настройка переменных окружения

Добавьте в `.env`:

```env
# MCP Fetch Server
MCP_FETCH_SERVER_URL=http://localhost:3000
MCP_FETCH_ENABLED=true
MCP_FETCH_TIMEOUT=30.0
```

### 2. Запуск MCP Fetch Server

MCP Fetch Server должен быть запущен и доступен по указанному URL. Пример конфигурации:

```json
{
  "server": {
    "port": 3000,
    "host": "localhost"
  },
  "endpoints": {
    "/fetch": "HTTP fetch endpoint",
    "/parse": "HTML parsing endpoint",
    "/health": "Health check endpoint"
  }
}
```

## Использование

### Базовое использование

```python
from services.mcp_fetch_service import get_mcp_fetch_service

# Получить экземпляр сервиса
service = get_mcp_fetch_service()

# Проверить доступность
is_available = await service.check_health()

# Получить сообщения из Telegram канала
messages = await service.fetch_telegram_channel_web("nizhnevartovsk_chp")

# Получить посты из VK группы
posts = await service.fetch_vk_group_web("typical.nizhnevartovsk")
```

### Интеграция в существующие сервисы

#### VK Monitor Service

MCP Fetch автоматически используется как fallback при недоступности VK API:

```python
from services.vk_monitor_service import fetch_group_wall

# Автоматически использует MCP если API недоступен
posts = await fetch_group_wall(group_id=-35704350, count=10)
```

#### Telegram Monitor Service

MCP Fetch используется для веб-парсинга публичных каналов:

```python
from services.telegram_monitor import TelegramMonitor

monitor = TelegramMonitor(...)
# При ошибках подключения автоматически используется MCP веб-парсинг
await monitor.join_channels()
```

### Проверка статуса

```python
from services.mcp_fetch_integration import check_mcp_availability

status = await check_mcp_availability()
print(status)
# {
#     "enabled": True,
#     "available": True,
#     "server_url": "http://localhost:3000",
#     "message": "MCP Fetch Server доступен"
# }
```

## API Endpoints MCP Fetch Server

### POST /fetch

Выполняет HTTP запрос:

```json
{
  "url": "https://example.com",
  "method": "GET",
  "headers": {
    "User-Agent": "MCP-Fetch/1.0"
  },
  "params": {
    "key": "value"
  }
}
```

Ответ:

```json
{
  "status": 200,
  "headers": {},
  "body": "...",
  "text": "..."
}
```

### POST /parse

Парсит HTML страницу:

```json
{
  "url": "https://example.com",
  "selector": ".post",
  "extract_text": true
}
```

Ответ:

```json
{
  "elements": [
    {
      "text": "Post content",
      "data-post": "123",
      "data-time": "1234567890"
    }
  ]
}
```

### GET /health

Проверка доступности сервера:

```json
{
  "status": "ok",
  "version": "1.0.0"
}
```

## Архитектура

```
┌─────────────────┐
│  VK Monitor     │
│  Service        │
└────────┬────────┘
         │
         ├─── VK API (основной метод)
         │
         └─── MCP Fetch (fallback)
                 │
                 └─── Веб-парсинг VK

┌─────────────────┐
│ Telegram Monitor│
│  Service        │
└────────┬────────┘
         │
         ├─── Telethon API (основной метод)
         │
         └─── MCP Fetch (fallback)
                 │
                 └─── Веб-парсинг Telegram
```

## Преимущества

1. **Надежность**: Автоматический fallback при недоступности API
2. **Гибкость**: Работа с публичными источниками без API ключей
3. **Единый интерфейс**: Одинаковый API для разных методов получения данных
4. **Расширяемость**: Легко добавить новые источники данных

## Ограничения

1. **Веб-парсинг менее надежен** чем официальные API
2. **Может быть медленнее** из-за парсинга HTML
3. **Требует запущенный MCP Fetch Server**
4. **Может нарушать ToS** некоторых сервисов (используйте ответственно)

## Troubleshooting

### MCP Fetch Server недоступен

1. Проверьте что сервер запущен:
   ```bash
   curl http://localhost:3000/health
   ```

2. Проверьте переменные окружения:
   ```python
   from services.mcp_fetch_service import MCP_FETCH_ENABLED, MCP_FETCH_SERVER_URL
   print(f"Enabled: {MCP_FETCH_ENABLED}, URL: {MCP_FETCH_SERVER_URL}")
   ```

3. Проверьте логи:
   ```python
   import logging
   logging.getLogger("services.mcp_fetch_service").setLevel(logging.DEBUG)
   ```

### Fallback не работает

Убедитесь что `MCP_FETCH_ENABLED=true` в `.env` и сервис правильно импортирован в модулях мониторинга.

## Примеры использования

### Парсинг конкретного канала

```python
from services.mcp_fetch_service import get_mcp_fetch_service

service = get_mcp_fetch_service()
messages = await service.fetch_telegram_channel_web("nizhnevartovsk_chp")

for msg in messages:
    print(f"{msg['timestamp']}: {msg['text'][:50]}...")
```

### Парсинг VK группы

```python
from services.mcp_fetch_service import get_mcp_fetch_service

service = get_mcp_fetch_service()
posts = await service.fetch_vk_group_web("typical.nizhnevartovsk")

for post in posts:
    print(f"Post {post['post_id']}: {post['text'][:50]}...")
```

## Интеграция в start_all_monitoring.py

MCP Fetch автоматически используется в основном цикле мониторинга при недоступности стандартных методов. Никаких дополнительных изменений не требуется.
