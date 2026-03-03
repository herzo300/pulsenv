# Скрипты и утилиты

Эта папка содержит вспомогательные скрипты для разработки, тестирования и обслуживания проекта.

## Структура

### `tests/`
Тестовые скрипты для проверки функциональности:
- `test_*.py` - тесты различных компонентов
- `test_*.html` - HTML тесты для браузера
- `check_*.py` - скрипты проверки состояния
- `verify_*.py` - скрипты верификации

### `maintenance/`
Скрипты обслуживания и обновления:
- `update_*.py` - скрипты обновления
- `fix_*.py` - скрипты исправления проблем
- `optimize_*.py` - скрипты оптимизации
- `run_all_services.py` - запуск всех сервисов
- `start_and_check_services.py` - запуск и проверка сервисов
- `daily_complaint_categorizer.py` - AI-анализ жалоб за текущий день и категоризация
- `daily_digest_telegram.py` - ежедневная сводка в Telegram: жалобы за день + анализ городской ситуации + советы (запускать в конце дня, напр. 23:00 MSK)

### `setup/`
Установка и проверка окружения:

### `servers/`
Локальные серверы для разработки:
- `mcp_fetch_server.py` — MCP Fetch на порту 3000 (JSON-RPC `fetch`). Нужен для Flutter-карты при запросе жалоб через MCP (firebase → localhost:3000).

### `deployment/`
Скрипты развертывания:
- `full_update.py` — полный цикл: деплой Worker + обновление бота (версия и меню)

## Обновление бота и Web App

Несколько способов (подробнее в [docs/ALTERNATIVE_BOT_UPDATE.md](../docs/ALTERNATIVE_BOT_UPDATE.md)):

| Способ | Команда |
|--------|--------|
| Полный цикл (деплой + бот) | `py scripts/deployment/full_update.py` |
| Только бот (меню + версия) | `py scripts/maintenance/update_and_verify_bot.py` или `full_update.py --no-deploy` |
| Из Telegram | Админ-панель → Управление ботом → «Обновить бота» |

Ссылок на карту/инфографику в боте уже с `?v=timestamp`.

## Использование

Все скрипты запускаются из корня проекта:

```bash
# Полный цикл: деплой Worker и обновление бота
py scripts/deployment/full_update.py

# Только обновление бота
py scripts/maintenance/update_and_verify_bot.py

# Дневная категоризация жалоб (фоновый цикл)
py scripts/maintenance/daily_complaint_categorizer.py

# Ежедневная сводка в Telegram (запускать раз в день, напр. 23:00 MSK — cron / Планировщик заданий)
py scripts/maintenance/daily_digest_telegram.py

# Проверка всех сервисов (Telegram бот, API :8000)
py scripts/maintenance/start_and_check_services.py
# Быстрая проверка тех же сервисов
py scripts/maintenance/check_all_services_quick.py

# Локальный MCP Fetch (для Flutter-карты)
py scripts/servers/mcp_fetch_server.py   # в отдельном терминале; затем запустить приложение (Windows) или flutter run

# Тесты
py scripts/tests/test_map_online.py
```
