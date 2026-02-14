# СообщиО (Soobshio) - Полная ревизия проекта

## 📋 Описание проекта

Городская платформа для сбора, анализа и визуализации обращений граждан о проблемах в Нижневартовске.

**Технологии:**
- **Backend**: Python, FastAPI, SQLAlchemy, SQLite
- **Frontend**: Flutter (Android, iOS, Web)
- **AI**: Anthropic Claude 3.5 Haiku для анализа текста
- **Maps**: OpenStreetMap (flutter_map), Google Maps
- **Clustering**: HDBSCAN для географической кластеризации

## 🏗️ Архитектура проекта

```
soobshio_project/
├── 📁 backend/                    # Backend API
│   ├── database.py               # БД подключение, engine, Session
│   ├── models.py                 # SQLAlchemy Report модель
│   ├── main_api.py               # API эндпоинты (/complaints, /clusters)
│   ├── auth.py                   # JWT/Telegram auth
│   └── init_db.py                # Инициализация БД
│
├── 📁 lib/lib/                    # Flutter приложение (Android/iOS/Web)
│   ├── screens/
│   │   ├── map_screen.dart       # Карта с жалобами
│   │   ├── complaints_list_screen.dart  # Список жалоб
│   │   ├── create_complaint_screen.dart # Создание жалобы
│   │   └── analytics_screen.dart   # Статистика
│   ├── services/
│   │   ├── api_service.dart      # HTTP клиент для backend
│   │   ├── ai_autofill_service.dart  # AI анализ текста
│   │   ├── hive_service.dart    # LocalStorage
│   │   └── location_service.dart # Geoloc
│   ├── models/
│   │   └── complaint.dart        # Модель данных
│   └── main.dart                 # Точка входа Flutter
│
├── 📁 services/                   # Python микросервисы
│   ├── ai_service.py             # Claude AI анализ
│   ├── geo_service.py            # Nominatim геокодинг
│   ├── cluster_service.py        # HDBSCAN кластеризация
│   └── telegram_parser.py        # Telegram мониторинг
│
├── 📁 routers/                    # FastAPI роутеры
│   └── reports.py                # CRUD для жалоб
│
├── 📁 core/                       # Core utilities
│   ├── config.py                 # Settings
│   ├── geoparse.py               # AI + Nominatim
│   └── monitor.py                # Telegram монитор (legacy)
│
├── 📁 tests/                      # Тесты
│   └── test_main_api.py          # API тесты
│
├── main.py                        # Точка входа FastAPI
├── requirements.txt               # Python зависимости
└── README.md                      # Документация
```

## 🚀 Установка и запуск

### 1. Backend (Python)

```bash
# Создать виртуальное окружение
python -m venv .venv
.venv\Scripts\activate

# Установить зависимости
pip install -r requirements.txt

# Настроить .env файл
copy .env.example .env

# Инициализировать БД
python -m backend.init_db

# Запустить API сервер
python main.py
```

API будет доступен на: **http://127.0.0.1:8000**

**Тестировать API:**
```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/categories
curl http://127.0.0.1:8000/complaints
curl -X POST http://127.0.0.1:8000/complaints \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"Test","latitude":61.034,"longitude":76.553}'
```

### 2. Frontend (Flutter)

```bash
# В корне Flutter проекта
cd lib

# Установить зависимости
flutter pub get

# Запустить на Android
flutter run -d android

# Запустить на iOS
flutter run -d ios

# Запустить на Chrome
flutter run -d chrome
```

**Тестировать Flutter:**
- Экран карты: показывает жалобы на OpenStreetMap
- Список жалоб: показывает все жалобы с фильтрацией
- Создание: добавление новой жалобы с AI анализом

## 📡 API Эндпоинты

### Основные

| Метод | Эндпоинт | Описание |
|-------|----------|----------|
| GET | `/` | Проверка работоспособности |
| GET | `/health` | Health check для Flutter |
| GET | `/categories` | Список категорий |
| GET | `/complaints` | Список жалоб с фильтрацией |
| GET | `/complaints/clusters` | Кластеры для карты |
| POST | `/complaints` | Создать жалобу (mobile app) |
| GET | `/stats` | Статистика |

### Формат запроса/ответа

**POST /complaints** (Mobile):
```json
{
  "title": "Яма на дороге",
  "description": "Большая яма на ул. Ленина",
  "category": "Дороги",
  "latitude": 61.034,
  "longitude": 76.553,
  "status": "open"
}
```

**GET /complaints**:
```json
[
  {
    "id": 1,
    "title": "Яма на дороге",
    "description": "Большая яма на ул. Ленина",
    "latitude": 61.034,
    "longitude": 76.553,
    "category": "Дороги",
    "status": "open",
    "created_at": "2026-02-07T12:00:00"
  }
]
```

## 🎯 Функциональность

### Backend

1. **API Сервер**
   - REST API для Flutter приложения
   - CORS для всех origins
   - Geospatial clustering (HDBSCAN)

2. **AI Сервис**
   - Анализ текста жалоб через Claude 3.5 Haiku
   - Определение категории (19 категорий)
   - Извлечение адреса

3. **Геосервисы**
   - Nominatim для адрес → координаты
   - Google Maps Street View

4. **Telegram Мониторинг**
   - Авто-сбор жалоб из каналов
   - AI анализ и категоризация
   - Авто-публикация в служебный канал

### Frontend (Flutter)

1. **Карта**
   - OpenStreetMap для Web/Android
   - Google Maps для iOS
   - Кластеризация точек
   - Маркеры с категориями

2. **Список жалоб**
   - Сортировка по дате
   - Фильтрация по категориям
   - Детальный просмотр

3. **Создание жалобы**
   - Геолокация пользователя
   - AI автозаполнение
   - Тесто-инпут

4. **Статистика**
   - Количество жалоб по категориям
   - Графики (fl_chart)
   - Последние жалобы

## 🗂️ Категории жалоб

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

## 🔧 Настройка

### .env файл

```env
# База данных
DATABASE_URL=sqlite:///./soobshio.db

# Telegram API (my.telegram.org)
TG_API_ID=12345678
TG_API_HASH=your_api_hash

# Anthropic Claude API (anthropic.com)
ANTHROPIC_API_KEY=sk-ant-api03-...

# JWT Secret
JWT_SECRET=your-jwt-secret-here

# Telegram Bot Token (BotFather)
BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11

# Target channel for auto-publish
TARGET_CHANNEL=-1001234567890
```

## 📊 Тестирование

### API Тесты

```bash
# Тесты для main.py
pytest tests/ -v

# Локальный тест
python -m pytest tests/test_main_api.py -v
```

### Интеграционное тестирование

1. Запустить Backend: `python main.py`
2. Открыть Flutter приложение
3. Проверить:
   - Загрузку карты
   - Отображение жалоб
   - Создание новой жалобы

## 🐛 Типичные проблемы

### API не отвечает

```bash
# Проверить статус
curl http://127.0.0.1:8000/health

# Перезапустить API
python main.py
```

### Flutter не подключается

```dart
// Проверить URL в api_service.dart
static const String _defaultBaseUrl = 'http://127.0.0.1:8000';
```

### БД ошибки

```bash
# Пересоздать БД
rm soobshio.db
python -m backend.init_db
```

## 📝 Структура данных

### Report (БД)

```sql
CREATE TABLE reports (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  category TEXT DEFAULT 'other',
  status TEXT DEFAULT 'open',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Complaint (Flutter)

```dart
class Complaint {
  final int id;
  final String title;
  final String description;
  final String category;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? createdAt;
  final String? source;
}
```

## 🚀 Деплой

### Backend (VPS/Docker)

```bash
docker compose up -d
```

### Flutter (App Store/Google Play)

```bash
flutter build apk
flutter build ios
```

## 📄 Лицензия

MIT

## 👥 Авторы

Soobshio Development Team
