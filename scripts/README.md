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

### `deployment/`
Скрипты развертывания:
- `deploy_now.py` — обновление секрета CF_API_TOKEN и запуск деплоя Cloudflare Worker через GitHub Actions
- `deploy_direct.py` — **прямой деплой через Cloudflare API** (без wrangler, без GitHub Actions) — **РЕКОМЕНДУЕТСЯ при проблемах**
- `deploy_npx.py` — деплой через `npx wrangler` (без глобальной установки wrangler)
- `full_update.py` — полный цикл: деплой Worker + обновление бота (версия и меню)

## Обновление бота и Web App

Несколько способов (подробнее в [docs/ALTERNATIVE_BOT_UPDATE.md](../docs/ALTERNATIVE_BOT_UPDATE.md)):

| Способ | Команда |
|--------|--------|
| Полный цикл (деплой + бот) | `py scripts/deployment/full_update.py` |
| Только деплой Worker | `py scripts/deployment/deploy_now.py` или `full_update.py --deploy-only` |
| Только бот (меню + версия) | `py scripts/maintenance/update_and_verify_bot.py` или `full_update.py --no-deploy` |
| Из Telegram | Админ-панель → Управление ботом → «Обновить бота» |

Ссылки на карту/инфографику в боте уже с `?v=timestamp`, поэтому после деплоя Worker пользователи получают свежую версию при следующем открытии; bump версии и обновление меню — по желанию.

## Использование

Все скрипты запускаются из корня проекта:

```bash
# Полный цикл: деплой Worker и обновление бота
py scripts/deployment/full_update.py

# Только обновление бота
py scripts/maintenance/update_and_verify_bot.py

# Только деплой Worker (выберите один из способов):
py scripts/deployment/deploy_direct.py  # Прямой деплой через API (рекомендуется)
py scripts/deployment/deploy_npx.py    # Через npx wrangler
py scripts/deployment/deploy_now.py     # Через GitHub Actions

# Тесты
py scripts/tests/test_map_online.py
```
