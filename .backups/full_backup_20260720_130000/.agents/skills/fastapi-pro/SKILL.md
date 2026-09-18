---
name: fastapi-pro
description: "FastAPI + SQLAlchemy 2.0 (async) + Pydantic V2 для проекта City Pulse / СообщиО (Нижневартовск). Асинхронные эндпоинты, JWT-аутентификация, миграции Alembic, тесты pytest. Адаптировано под стек проекта: main.py → services/Backend/app.py, 17 роутеров."
category: backend
risk: safe
source: community (adapted for City Pulse)
date_added: '2026-07-05'
project: Soobshio_project
---

# FastAPI Pro — City Pulse / СообщиО

Эксперт по асинхронному FastAPI-бэкенду проекта мониторинга городской среды Нижневартовска.

## 🎯 Применять в проекте когда

- Работа с бэкендом: `services/Backend/` (основное), `main.py` (точка входа), `backend/` (legacy-модули)
- Добавление/изменение роутеров (`/ai`, `/complaints`, `/reports`, `/map`, `/uk`, `/gamification`, `/vlm`, `/digest`, `/telegram` и др.)
- Работа с БД: PostgreSQL 16 (prod) / SQLite (dev), миграции Alembic
- Тестирование: `pytest -m pytest tests/test_smoke_api.py`
- Линтинг: `ruff check .` (конфиг в `ruff.toml`)

## 🏗 Архитектура проекта

```
main.py → services/Backend/app.py (FastAPI app, 17 роутеров)
          ↓
       core/config.py (Pydantic Settings, env)
          ↓
       alembic/ (миграции PostgreSQL)
```

**Точка входа:** `main.py` делегирует в `services/Backend/app.py`
**ASGI сервер:** Uvicorn, порт 8000 (контейнер `backend` в docker-compose)
**ORM:** SQLAlchemy 2.0 + asyncpg (асинхронный драйвер PostgreSQL)

## 🔑 Критичные env-переменные (см. core/config.py)

| Переменная | Назначение | Обязательна |
|------------|------------|-------------|
| `JWT_SECRET` | Секрет для JWT-токенов | ✅ |
| `PUBLIC_API_BASE_URL` | Базовый URL API | ✅ |
| `DATABASE_URL` | URL БД (asyncpg:// для prod) | ✅ |
| `DB_AUTO_CREATE` | `false` в prod после `alembic upgrade head` | — |
| `VLM_ENABLED` / `VLM_ON_DEMAND_ONLY` | Vision-Language Model по запросу | — |
| `ENABLE_AI_STACK` | Включить Docker profile `ai` (Ollama+LiteLLM) | — |

## 📋 Чек-лист для новых эндпоинтов в City Pulse

1. **Схема Pydantic V2** в `services/Backend/schemas/` (аннотированные типы, `Annotated`)
2. **Роутер** в `services/Backend/routers/<name>.py` с префиксом (см. таблицу роутеров в PROJECT_STRUCTURE.md)
3. **Асинхронная сессия БД** через dependency injection (`Depends(get_db)`)
4. **Миграция Alembic** при изменении схемы: `alembic revision --autogenerate -m "описание"`
5. **JWT-защита** для эндпоинтов пользователя (`Depends(get_current_user)` из `backend/auth.py`)
6. **Smoke-тест** в `tests/test_smoke_api.py` или `scripts/tests/`
7. **Ruff**: `ruff check services/Backend/routers/<name>.py`

## 🧱 Паттерны проекта (async-first)

```python
# Асинхронная сессия БД (SQLAlchemy 2.0 + asyncpg)
from sqlalchemy.ext.asyncio import AsyncSession

async def get_report(report_id: int, db: AsyncSession = Depends(get_db)):
    stmt = select(Report).where(Report.id == report_id)
    result = await db.execute(stmt)
    report = result.scalar_one_or_none()
    if not report:
        raise HTTPException(404, "Жалоба не найдена")
    return report
```

```python
# Pydantic V2 Settings (core/config.py)
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    jwt_secret: str
    public_api_base_url: str
    database_url: str
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
```

## 🗄 Основные таблицы БД

- `reports` — жалобы/инциденты (15+ полей, координаты, категории, verification_score)
- `users` — профили пользователей приложения
- `user_gamification`, `user_achievements`, `user_quests` — геймификация
- `daily_digest` — ежедневный AI-анализ
- `geo_subscriptions` — push-подписки по геозонам
- `camera_metrics` — метрики городских камер

## ✅ Валидация изменений

```bash
# Линтинг
ruff check services/Backend/

# Smoke-тесты API
python -m pytest tests/test_smoke_api.py -q

# Миграции (production)
docker compose exec backend alembic upgrade head

# Health check
curl http://localhost:8000/  # корневой health endpoint
```

## 🚫 НЕ применять когда

- Задача не связана с FastAPI/Python бэкендом
- Нужен фронтенд (Flutter) → используй flutter-expert
- Нужна Docker-оркестрация → используй docker-expert
- Нужна работа с AI-провайдерами → используй llm-prompt-optimizer
