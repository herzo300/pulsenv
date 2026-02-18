# Cloudflare Worker — Прокси для Soobshio

Worker проксирует запросы к внешним API и предоставляет веб-приложения для Telegram.

## Структура

- `worker.js` — собранный файл (генерируется `build_worker.py`)
- `build_worker.py` — скрипт сборки (объединяет HTML и JS в константы)
- `app.html` + `app_script.js` → `APP_HTML`
- `map.html` + `map_script.js` → `MAP_HTML`
- `info.html` + `info_script.js` → `INFO_HTML`
- `wrangler.toml` — конфигурация Cloudflare Worker

## Сборка

```bash
python build_worker.py
```

## Деплой

### Способ 1: Через GitHub Actions (автоматически)

```bash
python scripts/deployment/deploy_now.py
```

Этот скрипт:
1. Обновляет секрет `CF_API_TOKEN` в GitHub
2. Триггерит workflow `.github/workflows/deploy-worker.yml`
3. GitHub Actions автоматически деплоит worker

### Способ 2: Через wrangler CLI

```bash
npm install -g wrangler
wrangler login
cd cloudflare-worker
python deploy.py
```

## Endpoints

- `/health` — статус worker
- `/app` — Unified Web App (Telegram)
- `/map` — Карта (legacy)
- `/info` — Инфографика
- `/infographic-data` — JSON данные инфографики
- `/firebase/*` → проксирует на Firebase RTDB
- `/openai/*` → проксирует на OpenAI API
- `/anthropic/*` → проксирует на Anthropic API

## Проверка

```bash
# Health
curl https://anthropic-proxy.uiredepositionherzo.workers.dev/health

# App
curl https://anthropic-proxy.uiredepositionherzo.workers.dev/app?v=test

# Firebase
curl "https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase/complaints.json?orderBy=\"\$key\"&limitToFirst=1"
```
