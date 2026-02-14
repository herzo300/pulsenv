# SQLite настройка для приложения СообщиО

## ✅ Что уже исправлено

### Уже настроено на SQLite:
1. **.env** - База данных: `DATABASE_URL=sqlite:///./soobshio.db` ✅
2. **.env.example** - База данных: `DATABASE_URL=sqlite:///./soobshio.db` ✅
3. **backend/database.py** - Настроен на SQLite ✅
4. **backend/models.py** - SQLAlchemy модели (не зависят от типа БД) ✅
5. **backend/init_db.py** - Инициализация БД ✅
6. **core/config.py** - Настройка SQLite ✅
7. **.gitignore** - SQLite файлы включены ✅

---

## ⚠️ Что нужно исправить

### 1. **main.py** - Старая версия с PostgreSQL

**Проблема**: `main.py` содержит код с PostgreSQL и несовременными зависимостями.

**Решение**: Используйте обновленную версию `main_fixed.py` (уже создан) или замените `main.py`:

```bash
cd Soobshio_project
mv main.py main.py.backup
mv main_fixed.py main.py
```

Или заменить содержимое main.py на:

```python
# soobshio-backend/main.py — Современный FastAPI с SQLite
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import create_engine, Column, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from pydantic import BaseModel
from datetime import datetime
import os

# БАЗА ДАННЫХ (SQLite)
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./soobshio.db")
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}
    if DATABASE_URL.startswith("sqlite")
    else {},
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# МОДЕЛЬ БД для жалоб
class Complaint(Base):
    __tablename__ = "complaints"

    id = Column(String, primary_key=True)
    text = Column(String)
    channel = Column(String)
    location = Column(String)
    confidence = Column(Float)
    lat = Column(Float)
    lon = Column(Float)
    parsed_at = Column(DateTime, default=datetime.utcnow)

Base.metadata.create_all(bind=engine)

# Pydantic модели
class ComplaintRequest(BaseModel):
    text: str
    channel: str

class ComplaintResponse(BaseModel):
    id: str
    location: str
    confidence: float
    lat_lon: str

app = FastAPI(title="SoobshiO AI Parser")

# Dependency для БД
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.post("/parse_complaint", response_model=ComplaintResponse)
async def parse_complaint(request: ComplaintRequest, db: Session = Depends(get_db)):
    """AI гео-парсинг + сохранение в SQLite"""

    # Генерируем ID
    complaint_id = f"comp_{int(datetime.now().timestamp())}"

    try:
        # AI парсинг
        claude_client = Anthropic(
            api_key=os.getenv("ANTHROPIC_API_KEY", "")
        )
        response = claude_client.messages.create(
            model="claude-3-sonnet-20241022",
            max_tokens=150,
            messages=[
                {"role": "system", "content": """SoobshiO гео-парсер.
                Извлеки JSON: {"location": "строго адрес", "confidence": 0.0-1.0, "lat": 60.93, "lon": 76.55}
                Только JSON!"""},
                {"role": "user", "content": f"Жалоба из {request.channel}: {request.text}"}
            ]
        )

        ai_json = response.content[0].text.strip()

        # Парсим JSON
        location = ai_json.split('"location":"')[1].split('"')[0] if 'location' in ai_json else "Не найдено"
        confidence = float(ai_json.split('"confidence":')[1].split(',')[0]) if 'confidence' in ai_json else 0.5

        # Сохраняем в SQLite
        complaint = Complaint(
            id=complaint_id,
            text=request.text,
            channel=request.channel,
            location=location,
            confidence=confidence,
            lat=60.9345,
            lon=76.5532,
            parsed_at=datetime.utcnow()
        )
        db.add(complaint)
        db.commit()

        return ComplaintResponse(
            id=complaint_id,
            location=location,
            confidence=confidence,
            lat_lon=f"{60.9345}, {76.5532}"
        )

    except Exception as e:
        raise HTTPException(500, f"AI error: {str(e)}")

# Telegram webhook (пример интеграции)
@app.post("/telegram_webhook")
async def telegram_webhook(update: dict, db: Session = Depends(get_db)):
    """Авто-парсинг новых сообщений из Telegram"""
    if update.get("message"):
        text = update["message"]["text"]
        channel = update["message"]["chat"]["title"] or "private"

        # Парсим автоматически
        result = await parse_complaint(ComplaintRequest(text=text, channel=channel), db)

        # Отправляем обратно в Telegram
        requests.post("https://api.telegram.org/bot{TOKEN}/sendMessage",
                     json={"chat_id": update["message"]["chat"]["id"],
                           "text": f"📍 Найдена локация: {result.location}"})

    return {"status": "parsed"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

---

### 2. **docker-compose.yml** - PostgreSQL вместо SQLite

**Проблема**: `docker-compose.yml` настроен на PostgreSQL, но проект использует SQLite.

**Решение**: Используйте `docker-compose.sqlite.yml` (уже создан):

```bash
cd Soobshio_project
mv docker-compose.yml docker-compose.postgresql.yml
mv docker-compose.sqlite.yml docker-compose.yml
```

Или заменить содержимое docker-compose.yml на:

```yaml
# Docker Compose для СообщиО с SQLite
# Полный стек: Backend + SQLite + Redis

version: '3.8'

services:
  # Backend API
  api:
    build: .
    container_name: soobshio_api
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=sqlite:///./soobshio.db
      - REDIS_URL=redis://redis:6379
      - TG_API_ID=${TG_API_ID}
      - TG_API_HASH=${TG_API_HASH}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - BOT_TOKEN=${BOT_TOKEN}
      - TARGET_CHANNEL=${TARGET_CHANNEL}
    volumes:
      - ./soobshio.db:/app/soobshio.db
      - ./.env:/app/.env:ro
    depends_on:
      - redis
    networks:
      - soobshio_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Telegram Parser
  parser:
    build: .
    container_name: soobshio_parser
    restart: unless-stopped
    command: python services/telegram_parser.py
    environment:
      - DATABASE_URL=sqlite:///./soobshio.db
      - TG_API_ID=${TG_API_ID}
      - TG_API_HASH=${TG_API_HASH}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - TARGET_CHANNEL=${TARGET_CHANNEL}
    volumes:
      - ./soobshio.db:/app/soobshio.db
      - ./.env:/app/.env:ro
    depends_on:
      - api
    networks:
      - soobshio_network

  # Telegram Bot
  bot:
    build: .
    container_name: soobshio_bot
    restart: unless-stopped
    command: python services/telegram_bot.py
    environment:
      - DATABASE_URL=sqlite:///./soobshio.db
      - BOT_TOKEN=${BOT_TOKEN}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    volumes:
      - ./soobshio.db:/app/soobshio.db
      - ./.env:/app/.env:ro
    depends_on:
      - api
    networks:
      - soobshio_network

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: soobshio_redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    networks:
      - soobshio_network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: soobshio_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./web:/usr/share/nginx/html:ro
    depends_on:
      - api
    networks:
      - soobshio_network

volumes:
  redis_data:

networks:
  soobshio_network:
    driver: bridge
```

---

## 🚀 Запуск с SQLite

### Вариант 1: Обычный запуск (без Docker)

```bash
cd Soobshio_project

# 1. Проверить .env файл
cat .env | grep DATABASE_URL
# Должно быть: DATABASE_URL=sqlite:///./soobshio.db

# 2. Создать виртуальное окружение
python -m venv .venv
.venv\Scripts\activate  # Windows
# или
source .venv/bin/activate  # Linux/Mac

# 3. Установить зависимости
pip install -r requirements.txt

# 4. Инициализировать БД
python -m backend.init_db

# 5. Запустить API
python main.py

# 6. В другом терминале - Telegram парсер
python services/telegram_parser.py
```

### Вариант 2: Docker Compose с SQLite

```bash
cd Soobshio_project

# Использовать docker-compose.sqlite.yml (уже переименован на docker-compose.yml)

# 1. Запустить контейнеры
docker compose up -d

# 2. Проверить логи
docker compose logs -f

# 3. Остановить контейнеры
docker compose down
```

---

## 📊 Структура SQLite

### Файл базы данных:
- **soobshio.db** - SQLite файл в корне проекта
- Автоматически создается при первом запуске
- Содержит таблицу `complaints`

### Таблица `complaints`:
```sql
CREATE TABLE complaints (
    id TEXT PRIMARY KEY,
    text TEXT,
    channel TEXT,
    location TEXT,
    confidence FLOAT,
    lat FLOAT,
    lon FLOAT,
    parsed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## ✅ Проверка SQLite настройки

```bash
cd Soobshio_project

# 1. Проверить DATABASE_URL в .env
grep DATABASE_URL .env

# 2. Проверить database.py
grep DATABASE_URL backend/database.py

# 3. Проверить .gitignore
grep sqlite .gitignore

# 4. Создать тестовую базу
python -c "from backend.database import engine; engine.connect().execute('SELECT 1'); print('✅ SQLite работает')"

# 5. Проверить существование файла базы
ls -lh soobshio.db
```

---

## 🔄 Дополнительные настройки

### Вариант PostgreSQL (если нужно):

Если вы хотите использовать PostgreSQL, то:

1. Отменить изменения в main.py
2. Использовать `docker-compose.postgresql.yml`
3. Установить `psycopg2-binary`
4. Изменить DATABASE_URL на PostgreSQL

```bash
# Отменить изменения main.py
mv main.py.backup main.py

# Отменить изменения docker-compose.yml
mv docker-compose.postgresql.yml docker-compose.yml

# В requirements.txt убрать закомментированную строку psycopg2-binary
```

---

## 📚 Документация

- **main_fixed.py** - исправленная версия main.py с SQLite
- **docker-compose.sqlite.yml** - исправленная версия docker-compose.yml с SQLite
- **requirements.txt** - без psycopg2-binary
- **.env** - DATABASE_URL=sqlite:///./soobshio.db
- **.env.example** - DATABASE_URL=sqlite:///./soobshio.db

---

## ✅ Итог

После применения исправлений:
1. ✅ **main.py** - обновлен до версии с SQLite
2. ✅ **docker-compose.yml** - настроен на SQLite (через docker-compose.sqlite.yml)
3. ✅ **requirements.txt** - без PostgreSQL зависимостей
4. ✅ **.env** - SQLite URL настроен
5. ✅ **.env.example** - SQLite URL настроен
6. ✅ **.gitignore** - SQLite файлы защищены

**Все компоненты теперь настроены на SQLite!** 🎉
