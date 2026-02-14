# Исправления для приложения СообщиО

## 1. Файл: services/telegram_parser.py

### Проблема:
Строки 206-212 содержат неработающий код, который пытается отправить POST запрос к несуществующему эндпоинту `parse_complaint`.

### Исправление:
Удалить строки 206-212:

```python
response = requests.post("http://localhost:8000/parse_complaint", json={
    "text": message_text,
    "channel": "telegram_channel_xyz"
})
location = response.json()["extracted_location"]

# Кластеризуйте HDBSCAN и сохраните в PostgreSQL
```

### Описание:
Эти строки пытаются использовать переменную `message_text`, которая не существует, и эндпоинт `parse_complaint`, которого нет в API. Код должен использовать анализ, который уже получен в переменной `analysis`.

---

## 2. Файл: routers/reports.py

### Проблема:
Используется устаревший метод `.dict()` в Pydantic v2

### Исправление:
Заменить строку 21:

Было:
```python
db_report = Report(**report.dict())
```

Стало:
```python
db_report = Report(**report.model_dump())
```

---

## 3. Создать файл: .env.example

### Содержимое:

```env
# База данных
DATABASE_URL=sqlite:///./soobshio.db

# Telegram API (my.telegram.org)
TG_API_ID=your_api_id
TG_API_HASH=your_api_hash
TG_BOT_TOKEN=your:bot_token
TARGET_CHANNEL=-1003302334425

# Anthropic Claude API (anthropic.com)
ANTHROPIC_API_KEY=sk-ant-api03-...

# OpenAI API (fallback)
OPENAI_API_KEY=sk-proj-...

# JWT Secret
JWT_SECRET=your-jwt-secret

# Настройки AI провайдера
PREFERRED_PROVIDER=google
BIG_MODEL=gemini-2.5-pro
SMALL_MODEL=gemini-2.0-flash
```

### Действие:
1. Создать файл `.env.example` в корне проекта
2. Добавить содержимое выше
3. Убедиться, что `.env` НЕ коммитится в git (должен быть в .gitignore)

---

## 4. Обновить файл: requirements.txt

### Проблема:
Указывает на PostgreSQL, но проект использует SQLite

### Исправление:
Удалить или закомментировать строки 10:

Было:
```python
# Database
psycopg2-binary>=2.9.0  # PostgreSQL driver
```

Стало:
```python
# Database
# psycopg2-binary>=2.9.0  # PostgreSQL driver (заменено на SQLite)
```

Также добавить поддержку SQLite в database.py (уже есть, но проверьте, что драйвер установлен).

---

## 5. Удалить дубликат Flutter-кода

### Действие:
Удалить папку `lib/lib/` целиком, так как она содержит дубликат основного кода.

```bash
rm -rf Soobshio_project/lib/lib/
```

---

## 6. Удалить неиспользуемый package.json

### Действие:
Удалить файл `package.json` в корне проекта, так как это Node.js конфиг, не связанный с Flutter.

```bash
rm Soobshio_project/package.json
```

---

## 7. Объединить FastAPI приложения (опционально)

### Проблема:
Два FastAPI приложения (main.py и backend/main_api.py) создают путаницу.

### Вариант А: Поднимать оба приложения

1. Запустить `main.py` (дает `/`, `/reports`, CORS)
2. Запустить `backend/main_api.py` (дает `/complaints`, `/complaints/clusters`, `/stats` без CORS)

### Вариант Б: Объединить в одно приложение (рекомендуется)

Изменить `main.py`:

```python
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import create_engine, Column, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from pydantic import BaseModel
from datetime import datetime
import os
import httpx
from backend.main_api import app as backend_app
from backend.models import Report
from backend.database import SessionLocal, get_db as get_db_backend

app = FastAPI(title="СообщиО API", version="2.0.0")

# Подключаем CORS
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Импортируем роутеры
from routers.reports import router as reports_router

app.include_router(reports_router, prefix="/api", tags=["reports"])

# Добавляем эндпоинты из backend/main_api.py
app.include_router(backend_app.routes, prefix="", tags=["complaints"])
```

---

## 8. Проверить .gitignore

### Требование:
Добавить .env в .gitignore:

```gitignore
# Environment variables
.env

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python

# Virtual environments
.venv/
venv/
ENV/

# IDE
.vscode/
.idea/

# Database
*.db
*.sqlite
*.sqlite3

# Flutter
*.apk
*.ipa
*.dSYM/
flutter_*.lock

# Sessions
*.session
*.session-journal

# OS
.DS_Store
Thumbs.db
```

---

## 9. Добавить тесты для backend/main_api.py (рекомендуется)

### Создать файл: tests/test_main_api_complaints.py

```python
import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_complaints_list():
    response = client.get("/complaints?limit=10")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)

def test_complaints_cluster():
    response = client.get("/complaints/clusters?min_cluster_size=2")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)

def test_stats():
    response = client.get("/stats")
    assert response.status_code == 200
    data = response.json()
    assert "total" in data
    assert "by_category" in data
    assert "resolved" in data
    assert "pending" in data

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "version" in data
```

---

## 10. Настроить Telegram бот (если нужно)

### Файл: services/telegram_bot.py

Этот файл должен быть запущен отдельно и подключаться к тому же API, что и telegram_parser.py.

### Действие:
Убедиться, что Telegram бот:
1. Подключается к тому же API на порту 8000
2. Использует правильные эндпоинты (GET `/complaints` вместо POST `/parse_complaint`)

---

## Проверка после исправлений

1. Проверить запускается ли приложение:
```bash
python main.py
```

2. Проверить работу API:
```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/complaints
curl http://127.0.0.1:8000/complaints/clusters
curl http://127.0.0.1:8000/stats
```

3. Проверить запускается ли Telegram парсер:
```bash
python services/telegram_parser.py
```

4. Проверить тесты:
```bash
pytest tests/
```

---

## Дополнительные улучшения

### Кэширование геокодинга
В `services/geo_service.py` уже реализовано кэширование, но можно добавить TTL:

```python
import time
_geo_cache = {}
_geo_cache_ttl = {}

async def get_coordinates(address: str, ttl: int = 3600) -> Optional[Tuple[float, float]]:
    cache_key = address.lower().strip()
    current_time = time.time()

    # Проверяем кэш
    if cache_key in _geo_cache and cache_key in _geo_cache_ttl:
        if current_time - _geo_cache_ttl[cache_key] < ttl:
            return _geo_cache[cache_key]

    # ... код для получения координат

    _geo_cache[cache_key] = (lat, lon)
    _geo_cache_ttl[cache_key] = current_time

    return lat, lon
```

### Логирование ошибок
Добавить более детальное логирование в telegram_parser.py:

```python
except Exception as e:
    logger.error(f"Error sending to API: {e}", exc_info=True)
```

### Обработка ошибок AI
Добавить retry логику при ошибках AI:

```python
import tenacity

@tenacity.retry(stop=tenacity.stop_after_attempt(3), wait=tenacity.wait_exponential(multiplier=1, min=2, max=10))
async def analyze_complaint(text: str) -> dict:
    # ... существующий код
```

---

## Резюме исправлений

1. ✅ Удалить неработающий код из telegram_parser.py (строки 206-212)
2. ✅ Заменить .dict() на .model_dump() в reports.py
3. ✅ Создать .env.example
4. ✅ Обновить requirements.txt (отключить PostgreSQL)
5. ✅ Удалить папку lib/lib/
6. ✅ Удалить package.json
7. ⚠️ Объединить FastAPI приложения (опционально, но рекомендуется)
8. ✅ Проверить .gitignore
9. ⚠️ Добавить тесты (рекомендуется)
10. ⚠️ Настроить Telegram бот (если нужно)

После выполнения всех исправлений приложение будет работать стабильно и без ошибок.
