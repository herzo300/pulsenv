---
name: observability-engineer
description: "Наблюдаемость City Pulse: health checks 9 Docker-сервисов, structured logging, метрики (camera online/offline, очередь жалоб, AI-запросы), алерты при росте offline-камер (CAMERA_PROBE_ALERT_WEBHOOK → ntfy/Slack)."
category: observability
risk: safe
source: community (adapted for City Pulse)
date_added: '2026-07-05'
project: Soobshio_project
---

# Observability Engineer — City Pulse / СообщиО

Наблюдаемость за分布式-системой из 9 микросервисов. Городская система должна работать стабильно: мониторинг каналов не должен падать, AI-классификация — не молчать, камеры — быть под контролем.

## 🎯 Применять когда

- Настройка health checks для сервисов в `docker-compose.yml`
- Структурированное логирование в FastAPI/worker'ах
- Метрики состояния камер (`camera_metrics` таблица)
- Алерты при росте offline-камер (`CAMERA_PROBE_ALERT_WEBHOOK`)
- Диагностика падений: `scripts/maintenance/healthcheck_stack.sh`
- Добавление APM (Sentry/Langfuse для AI-вызовов)

## 📊 Что важно наблюдать в City Pulse

| Сервис | Ключевые метрики | Алерт при |
|--------|------------------|-----------|
| `backend` (FastAPI) | RPS, latency, 5xx, время ответа `/ai` | p99 > 2s, 5xx > 1% |
| `monitoring` (TG/VK) | Сообщений/час, % пропущенных спамом, глубина очереди | Очередь растёт / 0 сообщений час+ |
| `camera_probe` | Кол-во online/offline камер | Offline > порог (5+) |
| `postgres` | Connections, slow queries, DB size | Conns > 80, slow query > 5s |
| `redis` | Memory, evictions, pubsub lag | Memory > 80% |
| `ollama` / `litellm` | AI latency, tokens/sec, errors | Fallback на keyword |
| `viseron` | Webhook delivery, detections | Webhook fails |
| `nginx` | 5xx rate, SSL expiry | 5xx spike |

## 🏥 Health checks (docker-compose.yml)

```yaml
# Каждый критичный сервис должен иметь healthcheck
backend:
  healthcheck:
    test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/')"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 40s

postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U citypulse"]
    interval: 10s
    timeout: 5s
    retries: 5

redis:
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s

ollama:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"]
    interval: 60s  # AI-модель грузится долго
    start_period: 120s
```

## 📝 Структурированное логирование

```python
# services/Backend/app.py + все роутеры
import structlog  # или loguru
log = structlog.get_logger()

log.info("complaint_classified",
    complaint_id=report.id,
    category=report.category,
    confidence=score,
    provider="zai",  # или "ollama" / "keyword"
    latency_ms=234,
)
# ВАЖНО: не логировать полный текст жалобы (PII), только id
```

## 🚨 Алерты о камерах

```bash
# .env
CAMERA_PROBE_ALERT_WEBHOOK=https://ntfy.sh/citypulse-cameras
# или Slack webhook

# camera_probe → при росте offline-камер:
# POST на CAMERA_PROBE_ALERT_WEBHOOK с {"offline_count": N, "delta": +3}
```

```python
# services/Backend/routers/... или camera_probe worker
async def check_cameras_and_alert():
    offline = await get_offline_cameras()
    if len(offline) >= ALERT_THRESHOLD:
        await httpx.AsyncClient().post(
            settings.camera_probe_alert_webhook,
            json={
                "title": f"🔴 {len(offline)} камер offline",
                "body": ", ".join(c.name for c in offline[:5]),
                "priority": "high",
            }
        )
```

## 📈 Метрики для AI-стека (Langfuse-стиль)

```python
# Для каждого AI-вызова логировать:
log.info("ai_call",
    provider="zai" | "ollama" | "keyword",
    model="glm-5-turbo" | "gemma-4-e4b",
    prompt_tokens=N,
    completion_tokens=N,
    latency_ms=N,
    success=True/false,
    fallback_triggered=bool,
)
# Это позволяет считать cost/latency fallback-цепочки
```

## 🔧 scripts/maintenance/healthcheck_stack.sh

```bash
# Базовый healthcheck всех сервисов
#!/bin/bash
for svc in backend postgres redis monitoring camera_probe viseron nginx; do
  status=$(docker inspect --format='{{.State.Health.Status}}' \
    "citypulse-${svc}-1" 2>/dev/null)
  echo "$svc: ${status:-unknown}"
done

# HTTP health endpoint
curl -sf http://localhost:8000/ >/dev/null && echo "API: OK" || echo "API: FAIL"

# Камеры
curl -sf http://localhost:8000/api/cameras/status | jq '.offline_count'
```

## 📊 Полезные запросы для диагностики

```sql
-- Глубина очереди monitoring (если есть таблица очереди)
SELECT count(*) FILTER (WHERE status = 'pending') AS pending,
       count(*) FILTER (WHERE status = 'failed') AS failed
FROM reports;

-- Топ медленных AI-вызовов (если логируется в БД)
SELECT provider, avg(latency_ms), max(latency_ms), count(*)
FROM ai_call_log  -- гипотетическая таблица
WHERE created_at > now() - interval '1 hour'
GROUP BY provider;

-- Динамика offline-камер
SELECT name, count(*) FILTER (WHERE status='offline') AS offline_events
FROM camera_metrics
WHERE created_at > now() - interval '24 hours'
GROUP BY name
HAVING count(*) FILTER (WHERE status='offline') > 0
ORDER BY offline_events DESC;
```

## ✅ Чек-лист наблюдаемости

- [ ] Health checks на всех 9 сервисах в docker-compose.yml
- [ ] `/health` эндпоинт в FastAPI (или корневой `/`)
- [ ] Структурированные логи (JSON) в `logs/`
- [ ] Логи не содержат PII и секретов
- [ ] `camera_probe` шлёт алерты при offline > порога
- [ ] Логи ротируются (logrotate или Docker logging driver)
- [ ] Backup-алерт: проверка что `monitoring` шлёт сообщения (нет тишины)
- [ ] Дашборд: хотя бы текстовый `healthcheck_stack.sh` по крону
- [ ] SSL-сертификат Nginx: мониторинг срока действия

## 📦 Опционально (roadmap)

- **Sentry** — error tracking (Python SDK, `sentry-sdk[fastapi]`)
- **Langfuse** — trace AI-вызовов (для анализа качества/стоимости)
- **Prometheus + Grafana** — если вырастет
- **Loki** — централизованные логи

## 🚫 НЕ применять когда

- Нужна сама диагностика бага → debugger/diagnosing-bugs
- Нужна настройка Docker → docker-expert
- Это про безопасность → security-audit
