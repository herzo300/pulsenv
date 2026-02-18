# Деплой Cloudflare Worker

## Способ 1: Через wrangler CLI (рекомендуется)

### Установка wrangler
```bash
npm install -g wrangler
```

### Авторизация
```bash
wrangler login
```

### Деплой
```bash
cd cloudflare-worker
python deploy.py
# или
wrangler deploy
```

## Способ 2: Через GitHub Actions

Если у вас настроен GitHub Actions workflow:

```bash
cd scripts/deployment
python deploy_now.py
```

Этот скрипт:
1. Обновляет секрет `CF_API_TOKEN` в GitHub
2. Триггерит workflow `deploy-worker.yml`

## Способ 3: Ручной деплой через Cloudflare Dashboard

1. Откройте [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Выберите Workers & Pages
3. Найдите worker `anthropic-proxy`
4. Нажмите "Edit code"
5. Скопируйте содержимое `cloudflare-worker/worker.js`
6. Вставьте в редактор
7. Сохраните и задеплойте

## Проверка после деплоя

```bash
# Health endpoint
curl https://anthropic-proxy.uiredepositionherzo.workers.dev/health

# App endpoint
curl https://anthropic-proxy.uiredepositionherzo.workers.dev/app?v=test

# Firebase proxy
curl "https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase/complaints.json?orderBy=\"\$key\"&limitToFirst=1"
```

## Текущий статус

Worker URL: `https://anthropic-proxy.uiredepositionherzo.workers.dev`

Endpoints:
- `/health` - статус worker
- `/app` - Unified Web App (Telegram)
- `/map` - Карта (legacy)
- `/info` - Инфографика
- `/firebase/*` - Прокси для Firebase RTDB
- `/openai/*` - Прокси для OpenAI API
- `/anthropic/*` - Прокси для Anthropic API
