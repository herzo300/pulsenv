# Viseron в Soobshio

[Viseron](https://github.com/roflcoopter/viseron) — self-hosted NVR с локальным AI: motion/object detection, записи, web UI. Используется для автоматических алертов с городских камер.

## Зачем он в проекте

| Возможность | Польза для «Пульса города» |
|-------------|----------------------------|
| Object detection (person, car, dog…) | Скопления людей, стаи собак, заторы → маркер на карте |
| Motion detection | Сигнал «есть активность» на камере |
| Webhook (v3.3+) | Push-события в FastAPI без polling |
| Web UI (:8888) | Оператор смотрит live/events/timeline |
| Локальная обработка | Без облачных NVR |

**Не используем:** face recognition (ФЗ-152), license plate recognition в публичном контуре.

## Архитектура

```
HLS/RTSP камеры → Viseron NVR → webhook POST → /api/nvr/viseron/webhook
                                              → viseron_bridge.py
                                              → Report + push + Telegram
```

## Включение

1. В `.env`:

```env
VISERON_ENABLED=true
VISERON_WEBHOOK_TOKEN=your_random_token_here
```

2. Запуск (profile `monitoring`):

```bash
docker compose --profile monitoring up -d viseron
```

3. UI: `http://127.0.0.1:8888` (на сервере через SSH tunnel)

4. В `ops/viseron/config/config.yaml` укажите тот же `X-Viseron-Token`, что в `.env`.

## API

| Метод | URL | Описание |
|-------|-----|----------|
| GET | `/api/nvr/viseron/status` | Статус интеграции |
| POST | `/api/nvr/viseron/webhook` | Приём событий (header `X-Viseron-Token`) |

Тест вручную:

```bash
curl -X POST http://127.0.0.1:8000/api/nvr/viseron/webhook \
  -H "Content-Type: application/json" \
  -H "X-Viseron-Token: YOUR_TOKEN" \
  -d '{"camera":"nv_60let_10","label":"person","count":8,"description":"test crowd"}'
```
