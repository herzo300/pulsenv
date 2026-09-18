---
name: python-testing
description: "Тестирование Python-бэкенда City Pulse: pytest + pytest-asyncio для асинхронного FastAPI, smoke-тесты API (tests/test_smoke_api.py), тесты с БД (SQLite для dev), TDD red-green-refactor. Роутеры: /complaints, /map, /gamification и др."
category: testing
risk: safe
source: ECC (adapted for City Pulse)
date_added: '2026-07-05'
project: Soobshio_project
---

# Python Testing — City Pulse / СообщиО

Стратегии тестирования для асинхронного FastAPI-бэкенда городской системы мониторинга.

## 🎯 Применять когда

- Написание тестов для роутеров FastAPI (`services/Backend/routers/`)
- TDD: red-green-refactor для новых фич
- Smoke-тесты API перед деплоем (`tests/test_smoke_api.py`)
- Тесты БД-логики (миграции Alembic, модели SQLAlchemy)
- Покрытие критичных путей: классификация жалоб, геокодирование, JWT

## 📂 Структура тестов проекта

```
tests/
├── test_smoke_api.py          # Smoke-тесты API (основные эндпоинты)
├── conftest.py                # Общие fixtures (client, db_session, auth)
└── (расширять по мере роста)

scripts/tests/
├── test_map_online.py         # Тест карты (data/map_script.js, /map)
├── check_all_services.py      # Проверка всех сервисов
└── ...                        # Интеграционные/ручные тесты

ci_test.db                     # SQLite для тестов (вне git, но создаётся)
```

## 🧱 Async-тестирование (FastAPI + pytest-asyncio)

```python
# tests/conftest.py
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from services.Backend.app import app  # основное FastAPI приложение

@pytest_asyncio.fixture
async def client():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac

@pytest_asyncio.fixture
async def db_session():
    # SQLite in-memory для тестов
    async with aiosqlite.connect(":memory:") as db:
        # Создание схемы из миграций
        yield db

@pytest.fixture
def auth_headers():
    # JWT для тестового пользователя
    from backend.auth import create_access_token
    token = create_access_token({"sub": "test_user_id"})
    return {"Authorization": f"Bearer {token}"}
```

```python
# tests/test_smoke_api.py — паттерн smoke-теста
import pytest

@pytest.mark.asyncio
async def test_health_endpoint(client):
    """Корневой health check."""
    resp = await client.get("/")
    assert resp.status_code == 200

@pytest.mark.asyncio
async def test_get_complaints(client):
    """Список жалоб доступен."""
    resp = await client.get("/api/complaints")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)

@pytest.mark.asyncio
async def test_create_complaint_requires_auth(client):
    """Создание жалобы требует JWT."""
    resp = await client.post("/api/complaints", json={"text": "Яма на Ленина 15"})
    assert resp.status_code in (401, 403)

@pytest.mark.asyncio
async def test_create_complaint_authenticated(client, auth_headers):
    """Авторизованный пользователь может создать жалобу."""
    resp = await client.post(
        "/api/complaints",
        json={"text": "Яма на ул. Ленина, 15", "category": "road"},
        headers=auth_headers,
    )
    assert resp.status_code in (200, 201)
    data = resp.json()
    assert "id" in data
```

## 🎯 TDD для проекта (red-green-refactor)

1. **RED**: Напиши тест для новой фичи (провал)
2. **GREEN**: Минимальная реализация в роутере
3. **REFACTOR**: Улучшить, сохраняя зелёные тесты

```python
# Пример: новая фича «фильтр жалоб по категории»
# 1. RED
@pytest.mark.asyncio
async def test_filter_complaints_by_category(client):
    resp = await client.get("/api/complaints?category=road")
    assert resp.status_code == 200
    for c in resp.json():
        assert c["category"] == "road"

# 2. GREEN → реализовать в routers/complaints.py
# 3. REFACTOR → оптимизация запроса (postgres-best-practices)
```

## 📊 Покрытие

```bash
# Цель: 80%+ для бэкенда, 100% для auth и AI-классификации
pytest --cov=services/Backend --cov=backend --cov-report=term-missing
pytest --cov=services/Backend --cov-report=html  # htmlcov/index.html
```

**Критичные пути (100% покрытие):**
- `backend/auth.py` (JWT — критично для безопасности)
- AI-классификация жалоб (влияет на публикацию)
- Геокодирование (`core/geoparse.py` — точность координат)
- Адресный фильтр (что публикуется в @monitornv)

## 🏷 Маркеры pytest (pytest.ini или pyproject.toml)

```ini
[pytest]
testpaths = tests
python_files = test_*.py
asyncio_mode = auto
markers =
    slow:           метка медленных тестов
    integration:    интеграционные (с БД, контейнерами)
    unit:           модульные
    ai:             тесты AI (требуют ENABLE_AI_STACK)
```

```bash
pytest -m "not slow"           # быстрые
pytest -m integration          # только интеграционные
pytest -m "ai"                 # AI-тесты (нужен Ollama/LiteLLM)
pytest -x                      # стоп на первом fail
pytest --lf                    # последний провалившийся
```

## 🗄 Тесты с БД

```python
# SQLite in-memory для изоляции (быстро, без зависимостей)
# На CI — отдельная PostgreSQL в сервисе-контейнере
@pytest_asyncio.fixture
async def pg_session():
    # Только для integration-тестов
    engine = create_async_engine(
        "postgresql+asyncpg://test:test@localhost:5432/citypulse_test"
    )
    async with AsyncSession(engine) as session:
        yield session
        await session.rollback()
```

## 🤖 Моки внешних сервисов

```python
# Мок Z.AI / Ollama — чтобы тесты не зависели от внешних API
@pytest.fixture
def mock_ai_classify(monkeypatch):
    async def fake_classify(text):
        return {"category": "road", "confidence": 0.95, "address": None}
    monkeypatch.setattr("services.Backend.routers.ai.classify", fake_classify)

@pytest.fixture
def mock_telegram_send(monkeypatch):
    async def fake_send(*args, **kwargs):
        return {"message_id": 1}
    monkeypatch.setattr("services.Backend.routers.telegram.send_message", fake_send)
```

## ✅ Чек-лист перед коммитом

- [ ] `ruff check .` — без ошибок
- [ ] `python -m pytest tests/test_smoke_api.py -q` — зелёные
- [ ] Новая логика покрыта тестом
- [ ] Тесты не ломаются при `--cov` (нет ignore)
- [ ] Моки для внешних API (Z.AI, TG, VK, Ollama) — чтобы CI не падал
- [ ] Тесты детерминированные (без race conditions в async)

## 🚫 НЕ применять когда

- Тестирование Flutter-фронтенда → flutter-expert
- E2E тестирование через браузер → отдельный навык
- Нагрузочное тестирование → использовать Locust/k6 (отдельно)
