# Cloudflare Worker — прокси Anthropic API

## Быстрый деплой (без CLI)

1. Откройте https://dash.cloudflare.com
2. Workers & Pages → Create → Create Worker
3. Назовите: `anthropic-proxy`
4. Вставьте код из `worker.js`
5. Deploy
6. Скопируйте URL: `https://anthropic-proxy.YOUR_SUBDOMAIN.workers.dev`

## Деплой через CLI

```bash
npm install -g wrangler
cd cloudflare-worker
wrangler login
wrangler deploy
```

## Настройка проекта

В `.env` добавьте:

```env
ANTHROPIC_BASE_URL=https://anthropic-proxy.YOUR_SUBDOMAIN.workers.dev
```

Перезапустите бота — он автоматически подхватит прокси.

## Проверка

```bash
curl https://anthropic-proxy.YOUR_SUBDOMAIN.workers.dev/v1/messages \
  -H "x-api-key: YOUR_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-haiku-20240307","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'
```

## Лимиты (бесплатный план)

- 100,000 запросов/день
- 10ms CPU time/запрос (достаточно для прокси)
- Без ограничений по трафику
