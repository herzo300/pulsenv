# СообщиО (Soobshio) - Городская система жалоб

Платформа для сбора, обработки и анализа обращений граждан по городским проблемам Нижневартовска.

## Архитектура

```
soobshio_project/
├── main.py                    # FastAPI приложение (точка входа)
├── requirements.txt           # Python зависимости
├── .env                       # Конфигурация (API ключи)
├── backend/
│   ├── __init__.py           # Экспорт модулей
│   ├── database.py           # Подключение к БД, engine, get_db
│   ├── models.py             # SQLAlchemy модели (Report)
│   ├── main_api.py           # API эндпоинты (/complaints, /clusters, /stats)
│   ├── auth.py               # JWT авторизация, Telegram verification
│   └── init_db.py            # Инициализация таблиц
├── routers/
│   ├── __init__.py
│   └── reports.py            # CRUD для жалоб
├── services/
│   ├── __init__.py
│   ├── ai_service.py         # Claude AI анализ жалоб
│   ├── geo_service.py        # Nominatim геокодинг
│   ├── cluster_service.py    # HDBSCAN кластеризация
│   └── telegram_parser.py   # Telegram мониторинг каналов
├── core/
│   ├── __init__.py
│   ├── config.py             # Pydantic Settings
│   ├── geoparse.py           # Claude + Nominatim геопарсинг
│   └── monitor.py           # Telegram монитор (устаревший)
├── tests/
│   └── test_main_api.py      # Тесты API
└── web/                      # Frontend (Flutter/web)
```

## Запуск

### 1. Установка зависимостей

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Настройка .env

Создайте файл `.env` на основе примера:

```env
# База данных
DATABASE_URL=sqlite:///./soobshio.db

# Telegram API (from my.telegram.org)
TG_API_ID=your_api_id
TG_API_HASH=your_api_hash

# Anthropic Claude API (anthropic.com)
ANTHROPIC_API_KEY=sk-ant-api03-...

# JWT (для авторизации)
JWT_SECRET=your-jwt-secret

# Telegram бот (BotFather)
BOT_TOKEN=your:bot_token

# Канал для публикации (опционально)
TARGET_CHANNEL=@your_channel
```

### 3. Инициализация БД

```bash
python -m backend.init_db
```

### 4. Запуск API

```bash
python main.py
# или
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

API будет доступен: http://127.0.0.1:8000

## API Эндпоинты

### GET /
Проверка работоспособности

### GET /reports
Список всех жалоб

### POST /api/reports/
Создание новой жалобы
```json
{
  "title": "Яма на дороге",
  "description": "Большая яма на ул. Ленина",
  "lat": 61.034,
  "lng": 76.553,
  "category": "Дороги"
}
```

### GET /complaints
Список жалоб с фильтрацией
- `category` - фильтр по категории
- `limit` - лимит записей (по умолчанию 100)

### GET /complaints/clusters
Кластеризация жалоб для карты (HDBSCAN)

### GET /stats
Статистика системы

## Модули

### AI Service (`services/ai_service.py`)
Анализ текста жалоб через Claude 3.5 Haiku:
- Определение категории из 19 категорий
- Извлечение адреса
- Генерация краткого резюме

### Geo Service (`services/geo_service.py`)
Геокодинг через Nominatim (OpenStreetMap):
- Адрес → координаты
- Генерация Street View URL

### Cluster Service (`services/cluster_service.py`)
Кластеризация жалоб по географическому признаку с использованием HDBSCAN.

### Telegram Parser (`services/telegram_parser.py`)
Мониторинг Telegram каналов Нижневартовска:
- Автоматический сбор жалоб
- AI анализ и категоризация
- Геопарсинг адресов
- Публикация в служебный канал

## Категории жалоб

1. ЖКХ
2. Дороги
3. Благоустройство
4. Транспорт
5. Экология
6. Животные
7. Торговля
8. Безопасность
9. Снег/Наледь
10. Освещение
11. Медицина
12. Образование
13. Связь
14. Строительство
15. Парковки
16. Социальная сфера
17. Трудовое право
18. Прочее
19. ЧП

## Тесты

```bash
pytest tests/ -v
```

## Docker

```bash
docker compose up -d
```
