# Структура проекта СообщиО

## Обзор

Проект организован по модульному принципу с четким разделением ответственности.

## Основные директории

### `core/`
Ядро приложения - централизованная конфигурация и общие утилиты.
- `config.py` - централизованная конфигурация
- `http_client.py` - HTTP клиент

### `services/`
Бизнес-логика и сервисы приложения.
- `telegram_bot.py` - Telegram бот
- `telegram_monitor.py` - мониторинг Telegram каналов
- `vk_monitor_service.py` - мониторинг VK
- `firebase_service.py` - работа с Firebase
- `zai_service.py` - AI анализ текста
- `zai_vision_service.py` - AI анализ изображений
- `geo_service.py` - геолокация
- `admin_panel.py` - админ-панель
- `Frontend/` - Flutter мобильное приложение

### `backend/`
Backend API (FastAPI).
- `database.py` - настройка БД
- `models.py` - модели данных
- `main_api.py` - основной API

### `cloudflare-worker/`
Cloudflare Worker для прокси и веб-приложений.
- `worker.js` - основной скрипт Worker
- `map.html`, `map_script.js` - веб-приложение карты
- `info.html`, `info_script.js` - веб-приложение инфографики
- `build_worker.py` - сборка Worker

### `scripts/`
Вспомогательные скрипты.
- `tests/` - тестовые скрипты
- `maintenance/` - скрипты обслуживания
- `deployment/` - скрипты развертывания

### `docs/`
Документация проекта.
- `reports/` - отчеты о выполненных задачах
- `guides/` - руководства

## Основные файлы в корне

- `main.py` - точка входа FastAPI приложения
- `start_telegram_bot.py` - запуск Telegram бота
- `start_all_monitoring.py` - запуск мониторинга
- `requirements.txt` - зависимости Python
- `.env.example` - пример конфигурации
- `infographic_data.json` - данные для инфографики

## Запуск проекта

### Telegram бот
```bash
python start_telegram_bot.py
```

### Мониторинг
```bash
python start_all_monitoring.py
```

### API сервер
```bash
python main.py
```

### Все сервисы
```bash
python scripts/maintenance/run_all_services.py
```

## Конфигурация

Все настройки находятся в `.env` файле (см. `.env.example`).

Основные переменные:
- `TG_BOT_TOKEN` - токен Telegram бота
- `FIREBASE_RTDB_URL` - URL Firebase Realtime Database
- `OPENROUTER_API_KEY` - ключ OpenRouter для AI
- `CF_WORKER` - URL Cloudflare Worker

## База данных

SQLite база данных (`soobshio.db`) хранит:
- Пользователей
- Жалобы/отчеты
- Сессии

Firebase Realtime Database хранит:
- Жалобы для веб-приложения
- Данные инфографики

## Развертывание

### Cloudflare Worker
```bash
cd cloudflare-worker
wrangler deploy
```

### Локальное тестирование
```bash
python scripts/tests/test_map_online.py
python scripts/tests/check_all_services.py
```
