---
name: telegram-bot-builder
description: "Telegram-интеграции для City Pulse: бот @monitornv, мониторинг 8+ каналов + VK-пабликов, автопубликация жалоб, push-уведомления по геозонам. Python (aiogram/async), FastAPI webhook, работа с TG_BOT_TOKEN."
category: integration
risk: safe
source: vibeship-spawner-skills (adapted for City Pulse)
date_added: '2026-07-05'
project: Soobshio_project
---

# Telegram Bot Builder — City Pulse / СообщиО

Telegram-интеграции городской системы мониторинга Нижневартовска. Проект использует Telegram и как источник (мониторинг каналов), и как канал публикации (@monitornv), и для push-уведомлений пользователям.

## 🎯 Применять когда

- Работа с TG-ботом проекта (токен `TG_BOT_TOKEN`)
- Расширение мониторинга каналов (сервис `monitoring` в docker-compose)
- Автопубликация в @monitornv (конвейер обработки жалоб → публикация)
- Push-уведомления по геозонам (`GeoSubscriptions` в БД)
- Настройка webhook Telegram → FastAPI (`/telegram` роутер)
- Парсинг входящих сообщений TG/VK → классификация ИИ → геокодирование

## 🏗 Архитектура TG-интеграций в проекте

```
┌─────────────────────────────────────────────────────────────┐
│  Источники: 8+ TG-каналов + VK-паблики                       │
│         ↓                                                    │
│  monitoring worker (start_all_monitoring.py)                 │
│         ↓                                                    │
│  Спам-фильтр → ИИ-классификация → Адресный фильтр           │
│         ↓                                                    │
│  Геокодирование (core/geoparse.py) → координаты             │
│         ↓                                                    │
│  Сохранение в reports + публикация в @monitornv              │
│         ↓                                                    │
│  Push по геозонам (geo_subscriptions)                       │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Стек проекта для TG

| Компонент | Технология | Файл/Сервис |
|-----------|------------|-------------|
| Мониторинг worker | Python (async), aiogram/telethon | `start_all_monitoring.py`, сервис `monitoring` |
| Бот публикации | aiogram | бот @monitornv |
| Webhook в API | FastAPI роутер | `/telegram` (`telegram_router`) |
| Конфиг токена | Pydantic Settings | `core/config.py`, env `TG_BOT_TOKEN` |
| VK-мониторинг | VK API | в составе `start_all_monitoring.py` |

## 🔑 Ключевые env-переменные

```bash
TG_BOT_TOKEN=...              # основной токен бота
# Доп. токены для мониторинга конкретных каналов (если нужны отдельные сессии)
```

## 🧱 Паттерны проекта (async Python)

```python
# Webhook Telegram → FastAPI (роутер /telegram)
from fastapi import APIRouter, Request, HTTPException
from core.config import settings

router = APIRouter(prefix="/telegram")

@router.post("/webhook")
async def telegram_webhook(req: Request):
    update = await req.json()
    # Обработка обновления: классификация → геокодирование → публикация
    # См. services/Backend/routers/telegram_router.py
    ...
```

```python
# Асинхронная отправка уведомления по геозоне
async def notify_geo_subscribers(db: AsyncSession, report: Report):
    stmt = select(GeoSubscription).where(
        ST_DWithin(GeoSubscription.geom, report.geom, GeoSubscription.radius_m)
    )
    subs = (await db.execute(stmt)).scalars().all()
    for sub in subs:
        await bot.send_message(
            sub.user_tg_id,
            f"📍 Новая жалоба рядом: {report.address}\n📄 {report.category}"
        )
```

## 🔄 Конвейер обработки сообщения (см. TECHNICAL_DOCUMENTATION.md)

1. **Захват** сообщения из TG-канала или VK-паблика
2. **Спам-фильтр** отсекает рекламу и нерелевантный контент
3. **ИИ-классификация** (Z.AI GLM-5 Turbo / Ollama Gemma 4 / keyword fallback)
4. **Адресный фильтр**: маркируются ТОЛЬКО проблемы с конкретным адресом (улица + дом)
5. **Геокодирование** адреса → координаты (`core/geoparse.py`)
6. **Сохранение** в `reports` + **публикация** в @monitornv + **push** подписчикам

## ✅ Чек-лист для новых TG-функций

- [ ] Токен берётся из env (`TG_BOT_TOKEN`), не хардкод
- [ ] Async-клиент (aiogram/telethon), не блокирующий sync-вызовы
- [ ] Глобальный error handler (`bot.catch` / try-except в worker)
- [ ] Rate limiting (TG лимиты: ~30 msg/sec глобально)
- [ ] Сессии/состояние в БД или Redis, не in-memory (worker рестартует)
- [ ] Логирование в `logs/` (структурированный логгер)
- [ ] Typing-индикатор перед долгими операциями (`send_chat_action`)
- [ ] Тест: отправить тестовое сообщение в тестовый канал

## 🔒 Безопасность

- `TG_BOT_TOKEN` — только в `.env`, никогда в коде/образе
- Webhook endpoint проверяет секрет (настроить дополнительно)
- Не логировать полные сообщения пользователей (PII) — только id/хэш
- Проверка прав для админ-команд (RBAC из `backend/auth.py`)

## 📊 Связанные навыки

- `llm-prompt-optimizer` — для промптов классификации жалоб
- `postgres-best-practices` — для `reports`, `geo_subscriptions`
- `docker-expert` — для сервиса `monitoring` в docker-compose

## 🚫 НЕ применять когда

- Нужен VK-специфичный код без TG-части
- Нужна AI-классификация текста → используй llm-prompt-optimizer
- Нужна работа с фронтендом → flutter-expert
