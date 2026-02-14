# 🚀 Быстрый старт - Soobshio Project

## Установка и запуск

### 1. Backend (Python)

```bash
# Активировать виртуальное окружение
.venv\Scripts\activate

# Запустить API сервер
python main.py
```

**API будет доступен на:** http://127.0.0.1:8000

**Тесты API:**
```bash
# Health check
curl http://127.0.0.1:8000/health

# Категории
curl http://127.0.0.1:8000/categories

# Список жалоб
curl http://127.0.0.1:8000/complaints

# Создать жалобу
curl -X POST http://127.0.0.1:8000/complaints \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Test\",\"description\":\"Test\",\"latitude\":61.034,\"longitude\":76.553,\"category\":\"Дороги\"}"
```

### 2. Frontend (Flutter)

```bash
cd lib

# Установить зависимости
flutter pub get

# Запустить на Chrome
flutter run -d chrome
```

## 📊 Структура проекта

```
soobshio_project/
├── main.py                    # FastAPI приложение
├── backend/
│   ├── database.py           # БД подключение
│   ├── models.py             # SQLAlchemy модели
│   ├── main_api.py           # API endpoints
│   └── init_db.py            # Инициализация БД
├── lib/lib/                   # Flutter приложение
│   ├── screens/
│   │   ├── map_screen.dart   # Карта
│   │   └── create_complaint_screen.dart
│   └── services/
│       └── api_service.dart  # HTTP клиент
├── services/
│   ├── ai_service.py         # Claude AI
│   ├── geo_service.py        # Nominatim
│   └── telegram_parser.py    # Telegram мониторинг
└── tests/
    └── test_main_api.py      # Тесты
```

## 🎯 Функционал

### Backend
- ✅ REST API для Flutter
- ✅ AI анализ текста (Claude 3.5 Haiku)
- ✅ Геокодинг (Nominatim)
- ✅ HDBSCAN кластеризация
- ✅ Telegram мониторинг

### Frontend (Flutter)
- ✅ Карта с жалобами
- ✅ Список с фильтрацией
- ✅ Создание жалоб
- ✅ Статистика

## 🔧 API Эндпоинты

| Endpoint | Method | Описание |
|----------|--------|----------|
| `/health` | GET | Health check |
| `/categories` | GET | Список категорий |
| `/complaints` | GET | Список жалоб |
| `/complaints` | POST | Создать жалобу |
| `/complaints/clusters` | GET | Кластеры |
| `/stats` | GET | Статистика |

## ⚠️ Возможные проблемы

### Backend не запускается
```bash
# Установить зависимости
pip install fastapi uvicorn sqlalchemy python-dotenv httpx telethon anthropic numpy hdbscan requests

# Перезапустить
python main.py
```

### Flutter не подключается
Проверить URL в `lib/lib/services/api_service.dart`:
```dart
static const String _defaultBaseUrl = 'http://127.0.0.1:8000';
```

### БД ошибки
```bash
rm soobshio.db
python -m backend.init_db
```

## 📚 Документация

- Полная документация: `PROJECT_REVISION.md`
- API спецификация: Swagger UI на http://127.0.0.1:8000/docs
