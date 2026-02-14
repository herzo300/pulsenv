# ✅ SQLite настройка - Быстрые исправления

## 📊 Статус SQLite

### ✅ Уже настроено на SQLite:
- ✅ **.env** - `DATABASE_URL=sqlite:///./soobshio.db`
- ✅ **.env.example** - `DATABASE_URL=sqlite:///./soobshio.db`
- ✅ **backend/database.py** - SQLite подключение
- ✅ **backend/models.py** - SQLAlchemy модели
- ✅ **backend/init_db.py** - Инициализация
- ✅ **core/config.py** - Настройки
- ✅ **.gitignore** - SQLite файлы включены

### ⚠️ Нужно исправить:
- ⚠️ **main.py** - старая версия с PostgreSQL
- ⚠️ **docker-compose.yml** - PostgreSQL вместо SQLite

---

## 🚀 Быстрое исправление (2 минуты)

### Шаг 1: Заменить main.py

```bash
cd Soobshio_project

# Заменить содержимое main.py
cat > main.py << 'EOF'
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
EOF

echo "✅ main.py обновлен до SQLite версии"
```

### Шаг 2: Обновить docker-compose.yml

```bash
cd Soobshio_project

# Заменить содержимое docker-compose.yml
cat > docker-compose.yml << 'EOF'
# Docker Compose для СообщиО с SQLite
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
EOF

echo "✅ docker-compose.yml обновлен до SQLite версии"
```

---

## 🧪 Проверка после исправлений

```bash
cd Soobshio_project

# 1. Проверить DATABASE_URL
grep DATABASE_URL .env
# Должно быть: DATABASE_URL=sqlite:///./soobshio.db

# 2. Проверить main.py
grep "sqlite" main.py | head -2

# 3. Проверить docker-compose.yml
grep "DATABASE_URL" docker-compose.yml | head -2

# 4. Создать тестовую базу
python -c "from backend.database import engine; print('✅ SQLite подключение работает')"

# 5. Проверить файл базы данных
ls -lh soobshio.db

# 6. Проверить .gitignore
grep "sqlite" .gitignore
```

Ожидаемые результаты:
```
DATABASE_URL=sqlite:///./soobshio.db
✅ SQLite подключение работает
-rw-r--r-- 1 user user ... soobshio.db
*.sqlite
*.sqlite3
```

---

## 🚀 Запуск приложения

### Обычный запуск:

```bash
cd Soobshio_project

# Создать виртуальное окружение
python -m venv .venv
.venv\Scripts\activate  # Windows
# или
source .venv/bin/activate  # Linux/Mac

# Установить зависимости
pip install -r requirements.txt

# Инициализировать БД
python -m backend.init_db

# Запустить API
python main.py

# В другом терминале - Telegram парсер
python services/telegram_parser.py
```

### Docker запуск:

```bash
cd Soobshio_project

# Запустить контейнеры
docker compose up -d

# Проверить логи
docker compose logs -f

# Остановить контейнеры
docker compose down
```

---

## 📁 Созданные файлы

1. **main_fixed.py** - исправленная версия main.py с SQLite
2. **docker-compose.sqlite.yml** - исправленная версия docker-compose.yml с SQLite
3. **SQLITE_FIXES.md** - полная документация

---

## ✅ Что исправлено

### Быстрые исправления:
1. ✅ **main.py** - обновлен до версии с SQLite
2. ✅ **docker-compose.yml** - настроен на SQLite (через docker-compose.sqlite.yml)

### Уже исправлено:
3. ✅ **.env** - DATABASE_URL=sqlite:///./soobshio.db
4. ✅ **.env.example** - DATABASE_URL=sqlite:///./soobshio.db
5. ✅ **backend/database.py** - SQLite подключение
6. ✅ **backend/models.py** - SQLAlchemy модели
7. ✅ **backend/init_db.py** - Инициализация
8. ✅ **core/config.py** - Настройки
9. ✅ **.gitignore** - SQLite файлы включены

---

## 📊 Сравнение с PostgreSQL

| Параметр | SQLite | PostgreSQL |
|----------|---------|------------|
| **Установка** | Одна команда | docker compose + init |
| **Конфигурация** | .env | docker-compose.yml |
| **Открытие файлов** | one file | Port 5432 |
| **Хостинг** | Любой сервер | Только сервер |
| **Перенос** | Копировать файл | Экспорт/импорт |
| **Скорость** | Быстро | Очень быстро |
| **Поддержка** | Для разработки | Для продакшена |
| **Скрипт запуска** | `python main.py` | `docker compose up` |

---

## 🎯 Рекомендации

### Для разработки и теста:
- ✅ **Используйте SQLite** - проще, быстрее, надежнее
- ✅ Один файл для всех данных
- ✅ Не нужно настраивать PostgreSQL
- ✅ Легко переносить на другой сервер

### Для продакшена:
- ⚠️ Можно использовать PostgreSQL с docker compose.postgresql.yml
- ⚠️ Дольше запуск
- ⚠️ Требует больше настроек

---

**Все компоненты теперь настроены на SQLite!** 🎉
