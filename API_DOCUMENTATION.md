# API Документация СообщиО

## 📋 Обзор

API СообщиО обеспечивает доступ к:
- Жалобам пользователей
- Датасетам открытых данных (NVD, Нижневартовск)
- Мониторинг Telegram каналов
- AI анализу текста
- Статистике и аналитике

**Базовый URL**: `http://127.0.0.1:8000`

---

## 🔐 Аутентификация

В данный момент API не требует аутентификации для GET-запросов.
Для POST-запросов токен добавляется в будущем.

---

## 📡 Эндпоинты

### Здоровье системы

```http
GET /health

Response:
{
  "status": "ok",
  "database": "connected" | "disconnected",
  "telegram_monitor": "running" | "stopped",
  "version": "1.0.0"
}
```

---

### Категории

```http
GET /categories

Response:
{
  "categories": [
    {
      "id": "Doro",
      "name": "Дороги и ямы",
      "icon": "•",
      "color": "#818CF8"
    },
    {
      "id": "Svet",
      "name": "Освещение",
      "icon": "•",
      "color": "#818CF8"
    },
    ...
  ]
}
```

---

### Жалобы

#### Создание жалобы

```http
POST /complaints
Content-Type: application/json

Request:
{
  "title": "Яма на улице Ленина 15",
  "description": "Большая яма, опасно для пешеходов",
  "latitude": 60.93,
  "longitude": 76.57,
  "category": "Дороги",
  "status": "open"
}

Response:
{
  "id": 123,
  "title": "Яма на улице Ленина 15",
  "description": "Большая яма, опасно для пешеходов",
  "latitude": 60.93,
  "longitude": 76.57,
  "category": "Дороги",
  "status": "open",
  "created_at": "2024-02-11T12:30:00Z"
}
```

#### Получение списка

```http
GET /api/complaints?page=1&per_page=20

Response:
{
  "data": [
    {
      "id": 1,
      "title": "Яма на Ленина 15",
      "category": "Дороги",
      "status": "open"
    },
    ...
  ],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 47,
    "pages": 3
  }
}
```

---

### AI Анализ

```http
POST /ai/analyze
Content-Type: application/json

Request:
{
  "text": "Яма на улице Ленина 15, большая яма, опасно"
}

Response:
{
  "category": "Дороги",
  "address": "улица Ленина 15",
  "summary": "Большая яма, опасно для пешеходов",
  "confidence": 0.95
}
```

#### Статистика AI

```http
GET /ai/proxy/stats

Response:
{
  "total_requests": 156,
  "requests_by_provider": {
    "zai": 89,
    "anthropic": 45,
    "openai": 22
  },
  "requests_by_model": {
    "haiku": 67,
    "sonnet": 55,
    "gpt-4": 34
  },
  "average_response_time_ms": 450
}
```

---

## 🔒 NVD - Уязвимости

### Получение паспорта NVD

```http
GET /nvd/passport

Response:
{
  "success": true,
  "data": {
    "identifier": "8603032896-docagtext",
    "title": "Текст правовых актов главы города (главы администрации города) Нижневартовск",
    "description": "Открытые данные о городских документах...",
    "keywords": ["Нижневартовск", "город", "документы", "администрация"],
    "publisher": "Администрация города",
    "created": "2020-01-01T00:00:00.000Z",
    "modified": "2024-02-10T12:00:00.000Z",
    "source": "data.n-vartovsk.ru",
    "fields": [...],
    "examples": [...]
  },
  "fields": [...]
}
```

### Получение списка уязвимостей

```http
GET /nvd/vulnerabilities?limit=20

Response:
{
  "success": true,
  "vulnerabilities": [
    {
      "cve_id": "CVE-2024-1234",
      "title": "Windows Kernel Elevation of Privilege Vulnerability",
      "severity": "HIGH",
      "score": 7.8,
      "published": "2024-01-15T00:00:00.000Z",
      "modified": "2024-01-20T12:00:00.000Z"
    }
  ]
}
```

### Статистика NVD

```http
GET /nvd/statistics

Response:
{
  "success": true,
  "statistics": {
    "total_records": 15432,
    "total_datasets": 5,
    "last_updated": "2024-02-11T06:00:00.000Z",
    "size_mb": 45.7,
    "formats": ["JSON", "CSV", "XML"]
  }
}
```

---

## 🗄 Датасеты Нижневартовска

### Получение паспорта

```http
GET /datasets/passport

Response: тот же, что /nvd/passport
```

### Список датасетов

```http
GET /datasets/list?limit=50&offset=0

Response:
{
  "success": true,
  "datasets": [
    {
      "id": "roads_2023",
      "title": "Данные о дорогах города за 2023 год",
      "description": "Информация о состоянии дорог, ремонтах, асфальте...",
      "category": "Транспорт",
      "created": "2023-01-01T00:00:00.000Z",
      "modified": "2024-02-01T12:00:00.000Z",
      "size_mb": 125.4,
      "format": "CSV",
      "records_count": 15678
    },
    {
      "id": "urban_2024",
      "title": "Урбанистика и благоустройство",
      "description": "Данные о городских объектах, парках, скверах...",
      "category": "ЖКХ",
      "created": "2024-01-01T00:00:00.000Z",
      "modified": "2024-02-10T15:30:00.000Z",
      "size_mb": 87.2,
      "format": "JSON",
      "records_count": 2341
    }
  ]
}
```

### Детали датасета

```http
GET /datasets/{dataset_id}

Response:
{
  "success": true,
  "dataset": {
    "id": "roads_2023",
    "title": "Данные о дорогах города за 2023 год",
    "description": "Информация о состоянии дорог, ремонтах, асфальте...",
    "category": "Транспорт",
    "created": "2023-01-01T00:00:00.000Z",
    "modified": "2024-02-01T12:00:00.000Z",
    "size_mb": 125.4,
    "records_count": 15678,
    "format": "CSV",
    "download_url": "https://data.n-vartovsk.ru/api/v1/8603032896-docagtext/data/roads_2023.csv"
  }
}
```

### Поиск по данным

```http
GET /datasets/search?query=дороги&category=Транспорт&limit=10

Response:
{
  "success": true,
  "data": [
    {
      "id": "roads_2023",
      "title": "Данные о дорогах города за 2023 год"
      ...
    },
    {
      "id": "urban_2024",
      "title": "Урбанистика и благоустройство",
      ...
    }
  ],
  "count": 2
}
```

### Статистика датасетов

```http
GET /datasets/statistics

Response:
{
  "success": true,
  "statistics": {
    "total_records": 18019,
    "total_datasets": 5,
    "last_updated": "2024-02-11T08:00:00.000Z",
    "size_mb": 212.6,
    "formats": ["JSON", "CSV", "XML"]
  }
}
```

---

## 📡 Telegram Мониторинг

### Запуск мониторинга

```http
POST /telegram/monitor/start
Content-Type: application/json

Request:
{
  "api_id": 12345678,
  "api_hash": "abc123def4567890",
  "phone": "79991234567",
  "channels": ["@nizhnevartovsk_problems", "@soobshio_official"]
}

Response:
{
  "success": true,
  "message": "Мониторинг запущен для 2 каналов",
  "channels": ["@nizhnevartovsk_problems", "@soobshio_official"]
}
```

### Статус мониторинга

```http
GET /telegram/monitor/status

Response:
{
  "status": "running",
  "statistics": {
    "total_messages": 156,
    "by_category": {
      "Дороги": 45,
      "ЖКХ": 38,
      "Транспорт": 22,
      "Прочее": 51
    },
    "by_channel": {
      "@nizhnevartovsk_problems": 98,
      "@soobshio_official": 58
    }
  }
}
```

### Получение сообщений

```http
GET /telegram/monitor/messages?category=Дороги&limit=50

Response:
{
  "success": true,
  "messages": [
    {
      "timestamp": "2024-02-11T12:30:00Z",
      "source": "telegram",
      "channel": "@nizhnevartovsk_problems",
      "text": "Яма на улице Ленина 15",
      "category": "Дороги",
      "category_confidence": "high",
      "has_media": false,
      "photos": []
    }
  ],
  "count": 1
}
```

### Остановка мониторинга

```http
POST /telegram/monitor/stop

Response:
{
  "success": true,
  "message": "Мониторинг остановлен"
}
```

---

## 📊 Параметры запросов

### Пагинация

| Параметр | Тип | По умолчанию | Описание |
|-----------|------|----------------|------------|
| page | int | 1 | Номер страницы |
| per_page | int | 20 | Записей на странице |
| offset | int | 0 | Пропустить записей |

### Фильтрация

| Параметр | Тип | По умолчанию | Описание |
|-----------|------|----------------|------------|
| query | string | - | Поисковый запрос |
| category | string | - | Категория для фильтра |
| limit | int | 20 | Максимум записей |

### Telegram мониторинг

| Параметр | Тип | Описание |
|-----------|------|------------|
| api_id | int | - | Telegram API ID |
| api_hash | string | - | Telegram API Hash |
| phone | string | - | Номер телефона |
| channels | array | [] | Список каналов |
| category | string | - | Категория для фильтра |
| limit | int | 100 | Максимум сообщений |

---

## 🔒 Коды ответов

### Успех

| Код | Описание |
|------|----------|
| 200 | OK |
| 201 | Создано |

### Ошибки

| Код | Описание | Пример |
|------|----------|---------|
| 400 | Неверный запрос | {"success": false, "error": "Invalid parameter"} |
| 404 | Не найдено | {"success": false, "error": "Not found"} |
| 500 | Внутренняя ошибка | {"success": false, "error": "Internal error"} |

---

## 🔑 Rate Limits

| Тип запроса | Лимит | Период |
|--------------|-------|----------|
| GET запросы | 1000/час | Каждый час |
| POST запросы | 1000/час | Каждый час |
| Telegram API | 100/мин | Каждую минуту |

---

## 📈 Примеры использования

### Flutter (Dio)

```dart
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  baseUrl: 'http://127.0.0.1:8000',
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
));

// Создание жалобы
final response = await dio.post(
  '/complaints',
  data: {
    'title': 'Яма на Ленина 15',
    'description': 'Большая яма',
    'latitude': 60.93,
    'longitude': 76.57,
    'category': 'Дороги',
  },
);

print('Жалоба создана: ${response.data['id']}');
```

### Telegram мониторинг

```dart
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  baseUrl: 'http://127.0.0.1:8000',
);

// Запуск мониторинга
final response = await dio.post(
  '/telegram/monitor/start',
  data: {
    'channels': ['@nizhnevartovsk_problems'],
  },
);

print('Мониторинг запущен');
```

### Получение сообщений из Telegram

```dart
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  baseUrl: 'http://127.0.0.1:8000',
);

// Получение сообщений с фильтрацией
final response = await dio.get(
  '/telegram/monitor/messages',
  queryParameters: {
    'category': 'Дороги',
    'limit': 50,
  },
);

final messages = response.data['messages'];
print('Получено ${messages.length} сообщений');
```

### Статистика датасетов

```dart
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  baseUrl: 'http://127.0.0.1:8000',
);

// Получение статистики
final response = await dio.get('/nvd/statistics');

final stats = response.data['statistics'];
print('Всего записей: ${stats['total_records']}');
print('Датаасетов: ${stats['total_datasets']}');
print('Размер: ${stats['size_mb']} MB');
```

---

## 🔧 Webhook (Планируется)

Webhooks будут добавлены для отправки уведомлений о:
- Новых жалобах
- Обновлениях статусов
- Ответах от администрации

Пример payload webhook:
```json
{
  "event": "complaint_created",
  "data": {
    "id": 123,
    "title": "Яма на Ленина 15",
    "category": "Дороги",
    "status": "open"
  },
  "timestamp": "2024-02-11T12:30:00Z"
}
```

---

## 📚 Дополнительные ресурсы

- [Telegram документация](https://core.telegram.org/api)
- [Open Data Specification](https://data.n-vartovsk.ru/docs)
- [NVD документация](https://nvd.nist.gov/)
- [Dio документация](https://pub.dev/packages/dio)

---

## 🚀 Быстрый старт

### Минимальная конфигурация Flutter

```dart
// lib/services/api_service.dart
import 'package:dio/dio.dart';

class ApiService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:8000',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
  );

  static Dio get dio => _dio;

  static Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await dio.get(path, queryParameters: queryParameters);
    return response.data;
  }

  static Future<dynamic> post(String path, dynamic data) async {
    final response = await dio.post(path, data: data);
    return response.data;
  }
}
```

### Проверка соединения

```dart
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  baseUrl: 'http://127.0.0.1:8000',
);

// Проверка здоровья API
final response = await dio.get('/health');

if (response.statusCode == 200) {
  final data = response.data;
  print('Статус: ${data['status']}');
  print('База данных: ${data['database']}');
  print('Версия API: ${data['version']}');
} else {
  print('API недоступен');
}
```

---

## 📝 Версионирование

Текущая версия: **1.0.0**

История изменений:
- **1.0.0** (2024-02-11): Базовый API + Telegram мониторинг + NVD + Datасеты

---

**Дата последнего обновления**: 2024-02-11
