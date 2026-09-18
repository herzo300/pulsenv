# Структура проекта City Pulse (Soobshio)

Система мониторинга городской среды города Нижневартовск с AI-анализом жалоб.

## 📁 Директории

### Основные компоненты

| Директория | Назначение | Ключевые файлы |
|------------|------------|----------------|
| `core/` | Ядро системы: конфигурация, HTTP-клиент, геокодирование, мониторинг | `config.py`, `geoparse.py`, `monitor.py`, `http_client.py` |
| `backend/` | Устаревшие/общие модули: модели БД, авторизация, сервис жалоб | `database.py`, `models.py`, `auth.py`, `complaint_service.py`, `social_api.py` |
| `services/Backend/` | **Основной FastAPI бэкенд** (17 роутеров) | `app.py`, `main.py`, `routers/*.py` |
| `services/Frontend/` | **Flutter мобильное приложение** (20+ экранов) | `lib/main.dart`, `lib/screens/*.dart`, `lib/services/*.dart` |
| `scripts/` | Вспомогательные скрипты (см. ниже) | |

### РРЅС„СЂР°СЃС‚СЂСѓРєС‚СѓСЂР°

| Директория | Назначение |
|------------|------------|
| `ops/` | Конфигурация сервисов: Viseron, LiteLLM, Nginx |
| `ops/viseron/` | Конфиг Viseron NVR для видеонаблюдения (см. `ops/viseron/README.md`) |
| `ops/litellm/` | Конфиг LiteLLM прокси для AI |
| `ops/timeweb/` | Конфиг Nginx для Timeweb VPS |
| `models/` | ML модели: YOLO ONNX модель |
| `data/` | Runtime данные (игнорируется git) |
| `public/` | Статические HTML страницы (карта, инфографика, камеры) |

### Скрипты

| Директория | Назначение |
|------------|------------|
| `scripts/deployment/` | Скрипты деплоя на Timeweb VPS |
| `scripts/debug/` | Отладочные скрипты для диагностики сервисов |
| `scripts/maintenance/` | Скрипты обслуживания (запуск сервисов, обновление бота) |
| `scripts/tests/` | Тестовые скрипты |
| `scripts/tools/` | Утилиты: синхронизация, загрузка моделей, проверка портов |

### Документация

| Файл | Описание |
|------|----------|
| `README.md` | Быстрый старт, структура проекта |
| `PROJECT_STRUCTURE.md` | Этот файл — детальное описание структуры |
| `BUSINESS_MODEL.md` | Бизнес-модель монетизации, расчёты |
| `TECHNICAL_DOCUMENTATION.md` | Техническая документация v3.0 |
| `docs/ANDROID_APP_HARDENING.md` | Усиление безопасности Android приложения |
| `docs/LEGAL_COMPLIANCE_CHECKLIST.md` | Чеклист юридического соответствия |

## 🚀 Docker сервисы (9)

| Сервис | Порт | Описание |
|--------|------|----------|
| `postgres` | — | PostgreSQL 16 (БД) |
| `redis` | — | Redis 7.4 (кэш, очереди) |
| `backend` | 8000 | FastAPI API (основной бэкенд) |
| `monitoring` | — | Telegram + VK мониторинг (worker) |
| `camera_probe` | — | Проверка камер (worker) |
| `viseron` | 8888 | NVR видеонаблюдение (webhook → backend) |
| `ollama` | 11434 | Локальный LLM/VLM сервер |
| `litellm` | 4000 | AI прокси/роутер |
| `nginx` | 80, 443 | Reverse proxy + статика |

## 📡 FastAPI Роутеры (17)

| Роутер | Префикс | Описание |
|--------|---------|----------|
| `core` | `/` | Health check, корневые эндпоинты |
| `ai` | `/ai` | AI анализ текста и изображений |
| `complaints` | `/complaints` | Жалобы пользователей |
| `reports` | `/reports` | Отчёты |
| `admin_metrics` | `/admin/metrics` | Метрики администратора |
| `agent` | `/agent` | AI агент |
| `map_data` | `/map` | Данные для карты |
| `uk_ratings` | `/uk` | Рейтинги УК |
| `visual_search` | `/visual-search` | Визуальный поиск |
| `vlm` | `/vlm` | Vision-Language Model |
| `profile` | `/profile` | Профиль пользователя |
| `daily_digest` | `/digest` | Ежедневные дайджесты |
| `gamification` | `/gamification` | Геймификация (XP, достижения, квесты) |
| `telegram_router` | `/telegram` | Telegram интеграция |

## 🔑 Ключевые точки входа

| Файл | Роль |
|------|------|
| `main.py` | Главная точка входа (делегирует в `services/Backend/app`) |
| `services/Backend/app.py` | Основное FastAPI приложение |
| `services/Backend/main.py` | Uvicorn entry point |
| `start_all_monitoring.py` | Unified Telegram + VK monitoring worker |
| `start_camera_probe.py` | Camera probe service |
| `docker-compose.yml` | Оркестрация 9 сервисов |

## 🗄️ База данных

**PostgreSQL** (production) / **SQLite** (development)

Основные таблицы:
- `reports` — жалобы (15+ полей)
- `user_gamification` — геймификация пользователей
- `user_achievements` — достижения
- `user_quests` — квесты
- `city_memes` — мемы
- `camera_metrics` — метрики камер
- `gamification_stats` — статистика геймификации

## ⚙️ Конфигурация

Все настройки в `core/config.py` и `.env` файле.

**Критические переменные окружения:**
- `JWT_SECRET` — секрет для JWT токенов (обязательная)
- `PUBLIC_API_BASE_URL` — базовый URL API (обязательная)
- `TG_BOT_TOKEN` — токен Telegram бота
- `DATABASE_URL` — URL базы данных
- `POSTGRES_PASSWORD` — пароль PostgreSQL
- `REDIS_PASSWORD` — пароль Redis
- `VISERON_WEBHOOK_TOKEN` — секрет webhook Viseron → `/api/nvr/viseron/webhook`
- `ENABLE_AI_STACK` — `true` включает Docker profile `ai` (Ollama + LiteLLM) при bootstrap
- `VLM_ENABLED` / `VLM_ON_DEMAND_ONLY` — VLM только по POST `/vlm/describe`
- `CAMERA_PROBE_ALERT_WEBHOOK` — алерт при росте offline-камер (ntfy/Slack)
- `DB_AUTO_CREATE` — `false` в production после `alembic upgrade head`

## 🧪 Тестирование

```bash
# Smoke API tests
python -m pytest tests/test_smoke_api.py -q

# Alembic (production)
alembic upgrade head
```

## 📦 Зависимости

**Backend:**
- FastAPI + Uvicorn — веб-фреймворк
- SQLAlchemy + asyncpg — ORM
- python-jose — JWT
- httpx — HTTP-клиент
- paramiko — SSH (для деплоя)

**Frontend (Flutter):**
- provider — state management
- flutter_map — карты
- http — HTTP-клиент
- Various AI/ML пакеты

## 🔄 Разработка

1. **Клонировать репозиторий**
2. **Скопировать `.env.example` → `.env`**, заполнить переменные
3. **Установить зависимости:** `pip install -r requirements.txt`
4. **Запустить Docker:** `docker compose up -d`
5. **Дождаться health checks** всех сервисов

