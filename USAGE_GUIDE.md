# 📚 ИНСТРУКЦИИ ПО ИСПОЛЬЗОВАНИЮ

**Дата:** 12 февраля 2026
**Версия:** 2.0.0

---

## 🚀 ЗАПУСК BACKEND

### 1. Установка зависимостей
```bash
cd C:\Soobshio_project
pip install -r requirements.txt
```

### 2. Запуск сервера
```bash
python main.py
```

**Сервер запустится на:** `http://127.0.0.1:8000`

---

## 🔔 FCM (Firebase Cloud Messaging)

### 1. Регистрация FCM токена

**Endpoint:** `POST /api/fcm-token`

**Тело запроса:**
```json
{
  "token": "YOUR_FCM_TOKEN",
  "user_id": null,
  "device_type": "android"
}
```

**Пример через curl:**
```bash
curl -X POST http://127.0.0.1:8000/api/fcm-token \
  -H "Content-Type: application/json" \
  -d '{
    "token": "dQw4w9WgXcQ:APA91bGp5q5J5q5J5q5J5q5J5q5J5q5J5q5J5q5J5q5J5q5J5q5J",
    "user_id": null,
    "device_type": "android"
  }'
```

**Ответ:**
```json
{
  "success": true,
  "message": "FCM токен зарегистрирован",
  "token_key": "dQw4w9WgXcQ:APA91bGp5"
}
```

---

### 2. Список зарегистрированных токенов

**Endpoint:** `GET /api/fcm-tokens`

**Пример:**
```bash
curl http://127.0.0.1:8000/api/fcm-tokens
```

**Ответ:**
```json
{
  "success": true,
  "count": 2,
  "tokens": [
    {
      "token": "dQw4w9WgXcQ:APA91bGp5...",
      "user_id": null,
      "device_type": "android",
      "registered_at": "2026-02-12T10:00:00"
    }
  ]
}
```

---

### 3. Подписка на тему

**Endpoint:** `POST /api/fcm/subscribe`

**Доступные темы:**
- `all` - Все уведомления
- `clusters` - Уведомления о кластерах

**Пример:**
```bash
curl -X POST http://127.0.0.1:8000/api/fcm/subscribe \
  -H "Content-Type: application/json" \
  -d '{
    "token": "dQw4w9WgXcQ:APA91bGp5...",
    "topic": "clusters"
  }'
```

**Ответ:**
```json
{
  "success": true,
  "message": "Успешно подписаны на тему: clusters",
  "topic": "clusters"
}
```

---

### 4. Отписка от темы

**Endpoint:** `POST /api/fcm/unsubscribe`

**Пример:**
```bash
curl -X POST http://127.0.0.1:8000/api/fcm/unsubscribe \
  -H "Content-Type: application/json" \
  -d '{
    "token": "dQw4w9WgXcQ:APA91bGp5...",
    "topic": "clusters"
  }'
```

**Ответ:**
```json
{
  "success": true,
  "message": "Успешно отписаны от темы: clusters",
  "topic": "clusters"
}
```

---

## 🚨 Уведомления о кластерах (>5 жалоб)

### POST /api/notify-cluster

**Отправка уведомления о новом кластере (>5 жалоб)**

**Пример:**
```bash
curl -X POST http://127.0.0.1:8000/api/notify-cluster \
  -H "Content-Type: application/json" \
  -d '{
    "cluster_id": 1,
    "complaints_count": 7,
    "center_lat": 60.9368,
    "center_lon": 76.5681
  }'
```

**Ответ:**
```json
{
  "success": true,
  "message": "Уведомление отправлено 2 устройствам",
  "notifications_sent": 2,
  "cluster_id": 1,
  "complaints_count": 7
}
```

**Условие:** Уведомление отправляется только если `complaints_count > 5`

---

## 📱 Flutter: Использование Notification Service

### 1. Инициализация

```dart
import 'package:flutter/material.dart';
import 'package:soobshio/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация уведомлений
  await NotificationService.initialize();
  
  runApp(const MyApp());
}
```

### 2. Получение FCM токена

```dart
final token = NotificationService.fcmToken;
print('FCM Token: $token');
```

### 3. Подписка на тему

```dart
// Подписка на кластеры
await NotificationService.subscribeToTopic('clusters');

// Отписка от темы
await NotificationService.unsubscribeFromTopic('clusters');
```

### 4. Уведомление о кластере

```dart
// Показать уведомление о новом кластере
await NotificationService.showClusterNotification(
  clusterId: 1,
  complaintsCount: 7,
  lat: 60.9368,
  lon: 76.5681,
);
```

---

## 🤖 Telegram Bot

### Токен бота
```
8535229948:AAF5nvKxCU7nDpbimunheAP9eWRTC8R1R0g
```

### Запуск мониторинга

**Endpoint:** `POST /telegram/monitor/start`

**Пример:**
```bash
curl -X POST http://127.0.0.1:8000/telegram/monitor/start \
  -H "Content-Type: application/json" \
  -d '{
    "api_id": 12345678,
    "api_hash": "YOUR_API_HASH",
    "phone": "+79991234567",
    "channels": ["@nizhnevartovsk_problems", "@soobshio_official"]
  }'
```

**Ответ:**
```json
{
  "success": true,
  "message": "Мониторинг запущен для 2 каналов",
  "channels": ["@nizhnevartovsk_problems", "@soobshio_official"]
}
```

---

## 📊 Тестирование всех API

### Проверка здоровья API
```bash
curl http://127.0.0.1:8000/health
```

**Ответ:**
```json
{
  "status": "ok",
  "database": "connected",
  "telegram_monitor": "stopped",
  "version": "1.0.0"
}
```

### Получение категорий
```bash
curl http://127.0.0.1:8000/categories
```

**Ответ:**
```json
{
  "categories": [
    {
      "id": "ЖКХ",
      "name": "ЖКХ",
      "icon": "•",
      "color": "#818CF8"
    }
    // ... 28 категорий
  ]
}
```

### Получение жалоб
```bash
curl http://127.0.0.1:8000/complaints?limit=10
```

### Получение кластеров
```bash
curl http://127.0.0.1:8000/complaints/clusters
```

---

## 🎯 Полный список API Endpoint

### Health & Status
| Метод | Эндпоинт | Описание |
|------|-----------|----------|
| GET | /health | Проверка здоровья API |
| GET | /categories | Список категорий |

### Complaints
| Метод | Эндпоинт | Описание |
|------|-----------|----------|
| GET | /complaints | Список жалоб (пагинация) |
| POST | /complaints | Создание жалобы |
| GET | /complaints/{id} | Детали жалобы |
| GET | /complaints/clusters | Кластеры для карты |
| GET | /complaints/list | Список с фильтрацией |
| POST | /complaints/create | Создание через мониторинг |
| PUT | /complaints/{id}/status | Обновление статуса |
| GET | /complaints/statistics | Статистика по жалобам |

### AI
| Метод | Эндпоинт | Описание |
|------|-----------|----------|
| POST | /ai/analyze | AI анализ текста |
| GET | /ai/proxy/health | Проверка AI proxy |
| POST | /ai/proxy/analyze | Unified анализ |
| GET | /ai/proxy/stats | Статистика AI |

### Telegram Monitoring
| Метод | Эндпоинт | Описание |
|------|-----------|----------|
| POST | /telegram/monitor/start | Запуск мониторинга |
| POST | /telegram/monitor/stop | Остановка мониторинга |
| GET | /telegram/monitor/status | Статус мониторинга |
| GET | /telegram/monitor/messages | Список сообщений |
| POST | /telegram/monitor/post | Постинг сообщения |

### FCM
| Метод | Эндпоинт | Описание |
|------|-----------|----------|
| POST | /api/fcm-token | Регистрация токена |
| GET | /api/fcm-tokens | Список токенов |
| POST | /api/fcm-token/{key} | Обновление токена |
| DELETE | /api/fcm-token/{key} | Удаление токена |
| POST | /api/notify-cluster | Уведомление о кластере |
| POST | /api/fcm/subscribe | Подписка на тему |
| POST | /api/fcm/unsubscribe | Отписка от темы |
| GET | /api/fcm/subscriptions/{key} | Список подписок |

### NVD
| Метод | Эндпоинт | Описание |
|------|-----------|----------|
| GET | /nvd/passport | Паспорт NVD |
| GET | /nvd/vulnerabilities | Список уязвимостей |
| GET | /nvd/statistics | Статистика NVD |

### Data.N-Vartovsk
| Метод | Эндпоинт | Описание |
|------|-----------|----------|
| GET | /datasets/passport | Паспорт датасетов |
| GET | /datasets/list | Список датасетов |
| GET | /datasets/{id} | Детали датасета |
| GET | /datasets/statistics | Статистика датасетов |
| GET | /datasets/search | Поиск по датасетам |

---

## ✅ Чек-лист проверки

- [x] Backend запущен
- [x] Health check проходит
- [x] Категории загружаются (28 категорий)
- [x] FCM токен регистрируется
- [x] Подписка на тему работает
- [x] Отписка от темы работает
- [x] Уведомления о кластерах отправляются (>5)
- [x] Telegram мониторинг запускается
- [x] Telegram мониторинг останавливается
- [x] Статус мониторинга работает
- [x] AI анализ работает
- [x] Кластеры для карты работают
- [x] Статистика жалоб работает

---

## 🎉 Все функции работают!

**Telegram Bot:** ✅ Настроен
**FCM:** ✅ Полностью реализован
**Подписка:** ✅ Реализована
**Уведомления о кластерах (>5):** ✅ Реализованы

**Проект готов к продакшену!** 🚀
