# 🚀 ИНСТРУКЦИЯ ПО ЗАПУСКУ СООБЩИО

## 📱 Созданные файлы Flutter для Android

### Новые файлы:
1. **lib/services/api_service.dart** - API клиент для связи с backend
2. **lib/models/complaint.dart** - Модель жалобы
3. **lib/screens/map_screen.dart** - Экран карты OpenStreetMap
4. **lib/screens/complaints_list_screen.dart** - Список жалоб
5. **lib/screens/create_complaint_screen.dart** - Создание жалобы (3 шага)
6. **lib/screens/complaint_detail_screen.dart** - Детали жалобы
7. **lib/lib/main.dart** - Главный файл с навигацией

### Обновленные файлы:
1. **lib/pubspec.yaml** - Добавлены зависимости
2. **backend/main_api.py** - Новые endpoints для API
3. **lib/theme/app_theme.dart** - Современная тема
4. **web/index.html** - Конверсионный лендинг

## 🔧 Установка зависимостей Flutter

```bash
cd C:\Soobshio_project\lib

# Установка зависимостей
flutter pub get

# Для Android - проверка
flutter doctor

# Запуск на Android эмуляторе
flutter run

# Или собрать APK
flutter build apk --release
```

## 🗺️ Карта OpenStreetMap

В приложении используется **OpenStreetMap** (бесплатная, без API ключей):

```dart
// lib/screens/map_screen.dart
TileLayer(
  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
  subdomains: const ['a', 'b', 'c'],
  userAgentPackageName: 'com.soobshio.app',
)
```

## 🤖 Тестирование Telegram

### 1. Проверка переменных окружения

Создайте файл `.env` в корне проекта:

```env
# Telegram API (получить на https://my.telegram.org)
TG_API_ID=your_api_id
TG_API_HASH=your_api_hash

# Anthropic API (получить на https://console.anthropic.com)
ANTHROPIC_API_KEY=sk-ant-api03-...

# Целевой канал для публикации (опционально)
TARGET_CHANNEL=@your_channel_name

# База данных
DATABASE_URL=sqlite:///./soobshio.db
```

### 2. Запуск тестов

```bash
cd C:\Soobshio_project

# Запуск backend сервера (Терминал 1)
python run_backend.py

# Запуск тестов Telegram (Терминал 2)
python test_telegram_monitoring.py

# Запуск парсера Telegram (Терминал 3)
python services/telegram_parser.py
```

### 3. Что тестирует `test_telegram_monitoring.py`:

✅ **AI Анализ** - Claude анализирует текст и определяет категорию
✅ **Геопарсинг** - Преобразует адрес в координаты через Nominatim
✅ **Категории** - 19 категорий с эмодзи
✅ **Полный пайплайн** - От текста до публикации
✅ **Подключение к Telegram** - Проверка авторизации

## 📡 Запуск Backend API

```bash
cd C:\Soobshio_project

# Вариант 1: Через скрипт
python run_backend.py

# Вариант 2: Напрямую через uvicorn
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Вариант 3: Через PowerShell
.\.venv\Scripts\activate
uvicorn main:app --reload
```

API будет доступен:
- API: http://localhost:8000
- Документация: http://localhost:8000/docs
- Альтернатива: http://127.0.0.1:8000/redoc

## 📱 Запуск Flutter приложения

### Android:
```bash
cd C:\Soobshio_project\lib

# Проверка устройств
flutter devices

# Запуск на подключенном Android
flutter run

# Запуск в режиме релиза
flutter run --release

# Сборка APK
flutter build apk --release
```

### Настройка для Android:
В файле `lib/services/api_service.dart` уже настроены URL:
```dart
static String get baseUrl {
  if (kIsWeb) return 'http://127.0.0.1:8000';
  if (Platform.isAndroid) return 'http://10.0.2.2:8000'; // Android emulator
  return 'http://127.0.0.1:8000';
}
```

Для реального Android устройства замените на IP компьютера в локальной сети.

## 🧪 Проверка API Endpoints

### 1. Проверка работоспособности
```bash
curl http://localhost:8000/health
```

### 2. Получение списка жалоб
```bash
curl http://localhost:8000/complaints
```

### 3. Получение кластеров (для карты)
```bash
curl http://localhost:8000/complaints/clusters
```

### 4. Создание жалобы (POST)
```bash
curl -X POST http://localhost:8000/complaints \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Яма на дороге",
    "description": "Большая яма на ул. Ленина",
    "category": "Дороги",
    "latitude": 60.9392,
    "longitude": 76.5922,
    "address": "ул. Ленина, 25"
  }'
```

### 5. Получение категорий
```bash
curl http://localhost:8000/categories
```

### 6. Статистика
```bash
curl http://localhost:8000/stats
```

## 📊 Функции Flutter приложения

### 🗺️ Экран Карты:
- OpenStreetMap без API ключей
- Маркеры жалоб с цветами категорий
- Фильтр по категориям (чипы сверху)
- Zoom +/- кнопки
- Обновление данных
- FAB "Сообщить" - создание жалобы

### 📝 Создание жалобы (3 шага):
1. **Выбор категории** - 19 категорий с эмодзи
2. **Описание** - Заголовок, описание, адрес
3. **Локация** - Выбор на карте OpenStreetMap

### 📋 Список жалоб:
- Карточки с категорией и статусом
- Фильтр по категориям
- Pull-to-refresh
- Детали жалобы в BottomSheet

### 📊 Статистика (заглушка):
- Готов к расширению

## 🔌 Интеграция Telegram

### Мониторинг каналов:
```python
# services/telegram_parser.py
channels = [
    'nizhnevartovsk_chp',
    'adm_nvartovsk',
    'justnow_nv',
    'nv86_me',
    'nv_chp',
    # ... 12 каналов
]
```

### Автопубликация:
```python
# Отправка в целевой канал
if target_channel and client:
    await client.send_message(
        entity=target_channel,
        message=publish_text
    )
```

### Формат публикации:
```
🛣️ [Дороги] Яма на ул. Ленина

📍 Адрес: ул. Ленина, 25

👁 Street View: https://www.google.com/maps/@?api=1...

#дороги #СообщиО #Нижневартовск
```

## 🐛 Отладка

### Проблемы с API:
```bash
# Проверка доступности
curl http://localhost:8000/health

# Проверка CORS (для Flutter Web)
# Добавлено в serve_web.py:
# Access-Control-Allow-Origin: *
```

### Проблемы с Flutter:
```bash
# Очистка
flutter clean
flutter pub get

# Пересборка
flutter run
```

### Проблемы с Telegram:
```bash
# Удаление сессии и повторная авторизация
del soobshio_session.session
python services/telegram_parser.py
```

## 📁 Структура проекта

```
C:\Soobshio_project\
├── backend\              # FastAPI сервер
│   ├── main_api.py      # API endpoints
│   ├── database.py      # База данных
│   └── models.py        # SQLAlchemy модели
├── services\            # Сервисы
│   ├── telegram_parser.py   # Парсер Telegram
│   ├── ai_service.py        # Claude AI
│   ├── geo_service.py       # Геокодинг
│   └── cluster_service.py   # Кластеризация
├── lib\                 # Flutter проект
│   ├── lib\             # Dart код
│   │   ├── main.dart    # Главный файл
│   │   ├── services\    # API сервис
│   │   ├── models\      # Модели
│   │   ├── screens\     # Экраны
│   │   └── theme\       # Темы
│   └── pubspec.yaml     # Зависимости Flutter
├── web\                 # Web landing
│   └── index.html       # Лендинг
├── test_telegram_monitoring.py  # Тесты
├── run_backend.py       # Запуск сервера
└── serve_web.py         # Web сервер
```

## ✅ Чек-лист запуска

- [ ] Создан файл `.env` с API ключами
- [ ] Установлены Python зависимости: `pip install -r requirements.txt`
- [ ] Установлены Flutter зависимости: `flutter pub get`
- [ ] Запущен backend: `python run_backend.py`
- [ ] API доступен: http://localhost:8000/health
- [ ] Запущен парсер Telegram: `python services/telegram_parser.py`
- [ ] Запущено Flutter приложение: `flutter run`

## 🆘 Поддержка

При проблемах:
1. Проверьте `.env` файл
2. Запустите `python test_telegram_monitoring.py`
3. Проверьте API: `curl http://localhost:8000/health`
4. Проверьте Flutter: `flutter doctor`

---
**СообщиО v2.0** - Городская система жалоб Нижневартовска
