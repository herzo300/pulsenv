---
name: docker-expert
description: "Docker-оркестрация для проекта City Pulse: 9 сервисов в docker-compose.yml (FastAPI, PostgreSQL, Redis, monitoring, camera_probe, Viseron NVR, Ollama, LiteLLM, Nginx). Деплой на Timeweb Cloud VPS, multi-stage сборки, health checks, profiles."
category: devops
risk: safe
source: community (adapted for City Pulse)
date_added: '2026-07-05'
project: Soobshio_project
---

# Docker Expert — City Pulse / СообщиО

Docker-инфраструктура системы мониторинга Нижневартовска. Развёрнуто на Timeweb Cloud VPS с полной автономностью.

## 🎯 Применять когда

- Изменение `Dockerfile` или `docker-compose.yml`
- Добавление/удаление сервисов в оркестрации
- Проблемы со health checks, зависимостями сервисов, network
- Деплой на Timeweb: `scripts/deployment/`
- Оптимизация образов (multi-stage, layer caching)
- Настройка Docker profiles (`ai` для Ollama+LiteLLM)

## 🏗 Состав оркестрации (docker-compose.yml)

| Сервис | Порт | Назначение | Profile |
|--------|------|------------|---------|
| `backend` | 8000 | FastAPI API (основной бэкенд) | default |
| `postgres` | — | PostgreSQL 16 (БД) | default |
| `redis` | — | Redis 7.4 (кэш, очереди) | default |
| `monitoring` | — | Telegram + VK мониторинг (worker) | default |
| `camera_probe` | — | Проверка состояния камер (worker) | default |
| `viseron` | 8888 | NVR видеонаблюдение (webhook → backend) | default |
| `ollama` | 11434 | Локальный LLM/VLM сервер (Gemma 4 E4B) | `ai` |
| `litellm` | 4000 | AI-прокси/роутер (fallback chain) | `ai` |
| `nginx` | 80, 443 | Reverse proxy + статика + HTTPS | default |

## 🔑 Ключевые env-переменные для Docker

```bash
# .env (вне git, создаётся из .env.example / .env.production.template)
JWT_SECRET=...              # обязателен
PUBLIC_API_BASE_URL=...     # обязателен
DATABASE_URL=postgresql+asyncpg://citypulse:${POSTGRES_PASSWORD}@postgres:5432/citypulse
POSTGRES_PASSWORD=...
REDIS_PASSWORD=...
TG_BOT_TOKEN=...
VISERON_WEBHOOK_TOKEN=...   # секрет webhook Viseron → /api/nvr/viseron/webhook
ENABLE_AI_STACK=true        # включает profile ai (Ollama + LiteLLM)
VLM_ENABLED=false           # VLM только по POST /vlm/describe
VLM_ON_DEMAND_ONLY=true
CAMERA_PROBE_ALERT_WEBHOOK=...  # ntfy/Slack при росте offline-камер
DB_AUTO_CREATE=false        # ВАЖНО: false в prod после alembic upgrade head
```

## 📋 Стандартные операции

```bash
# Полный запуск инфраструктуры
docker compose up -d --build

# Только AI-стек (если был выключен)
docker compose --profile ai up -d ollama litellm

# Применить миграции в запущенный backend
docker compose exec backend alembic upgrade head

# Логи конкретного сервиса
docker compose logs -f --tail=100 monitoring

# Health checks всех сервисов
docker compose ps
docker inspect --format='{{.State.Health.Status}}' $(docker compose ps -q)

# Полная пересборка с нуля
docker compose down -v
docker compose up -d --build --force-recreate
```

## 🐳 Паттерны Dockerfile проекта

```dockerfile
# Multi-stage build (см. Dockerfile в корне)
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.12-slim AS runtime
RUN useradd -m -u 1001 appuser
WORKDIR /app
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local
COPY --chown=appuser:appuser . .
USER appuser
ENV PATH=/home/appuser/.local/bin:$PATH
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/')" || exit 1
CMD ["uvicorn", "services.Backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## 🌐 Конфигурация Nginx (ops/timeweb/nginx.conf)

```nginx
# Reverse proxy: HTTPS → backend (8000) + статика (public/)
# Webhook Viseron: /api/nvr/viseron/webhook → backend
# Раздача Flutter Web сборки
upstream backend {
  server backend:8000;
}
server {
  listen 443 ssl http2;
  server_name city-pulse.example.ru;
  
  location /api/ {
    proxy_pass http://backend;
    proxy_set_header X-Viseron-Token $http_x_viseron_token;
  }
  location / {
    root /usr/share/nginx/html;  # Flutter Web
    try_files $uri $uri/ /index.html;
  }
}
```

## ✅ Чек-лист ревью Docker-изменений

### Dockerfile
- [ ] Multi-stage build используется (отдельный builder/runtime)
- [ ] Non-root user (USER 1001) в runtime stage
- [ ] requirements.txt копируется ДО исходников (layer caching)
- [ ] `.dockerignore` исключает `.venv`, `data/`, `logs/`, `__pycache__`
- [ ] HEALTHCHECK определён для основного сервиса
- [ ] Версии базовых образов зафиксированы (`python:3.12-slim`, не `latest`)

### docker-compose.yml
- [ ] Зависимости сервисов с `condition: service_healthy`
- [ ] Health checks на всех критичных сервисах
- [ ] Volume для `postgres` (персистентность данных)
- [ ] Секреты через env, не в коде (`POSTGRES_PASSWORD`, `JWT_SECRET`)
- [ ] Сети изолированы (backend internal, frontend external)
- [ ] Restart policy: `unless-stopped` или `on-failure`
- [ ] Resource limits для worker-сервисов (monitoring, camera_probe)

### Безопасность
- [ ] Никаких секретов в образе (только env/runtime)
- [ ] `.env` в `.gitignore` (проверить — он уже там)
- [ ] gitleaks в pre-commit: `.gitleaks.toml` настроен
- [ ] Образы сканируются (Docker Scout / trivy)

## 🔧 Частые проблемы проекта

| Симптом | Причина | Решение |
|---------|---------|---------|
| Backend не отвечает | Не прошла миграция | `docker compose exec backend alembic upgrade head` |
| Viseron не доходит | Неверный `VISERON_WEBHOOK_TOKEN` | Сверить токен в env и в заголовке webhook |
| Ollama/LiteLLM не стартуют | `ENABLE_AI_STACK` не true | `docker compose --profile ai up -d` |
| Камеры offline | camera_probe не запущен | `docker compose logs camera_probe` |
| Redis переполняется | Нет TTL на ключах | Проверить `EX` в SET в backend коде |

## 🚫 НЕ применять когда

- Нужен Kubernetes → нужны отдельные манифесты (проект на docker compose)
- Нужно что-то специфичное для Timeweb CLI → см. `ops/timeweb/README.md`
- Нужна диагностика FastAPI-кода → используй fastapi-pro
