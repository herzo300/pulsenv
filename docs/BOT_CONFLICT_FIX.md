# Решение TelegramConflictError (Conflict: terminated by other getUpdates)

## Причина
Telegram позволяет только **один** активный long-polling (getUpdates) на один токен бота.

## Что сделано

### 1. Lock-файл (один экземпляр на машине)
- `data/telegram_bot.lock` — при запуске проверяется, не занят ли бот
- `scripts/maintenance/kill_old_bot.py` — остановить предыдущий экземпляр по lock-файлу

### 2. Режим Webhook (без getUpdates)
- `main.py` — endpoint `POST /webhook/telegram`
- `scripts/maintenance/run_bot_webhook.py` — установить webhook
- Требует: `WEBHOOK_BASE_URL` в `.env` (HTTPS)

### 3. Сброс webhook при polling
- Перед `start_polling` вызывается `delete_webhook`

## Если всё ещё конфликт

1. **Другой экземпляр на этой машине**
   ```bash
   py scripts/maintenance/kill_old_bot.py
   py start_telegram_bot.py
   ```

2. **Бот запущен на VPS/сервере**
   - Остановите его там (или переключитесь на webhook и держите только один источник обновлений)

3. **Переход на Webhook**
   - Добавьте в `.env`: `WEBHOOK_BASE_URL=https://your-domain.com`
   - Запустите `main.py` (uvicorn) так, чтобы он был доступен по этому URL
   - Запустите: `py scripts/maintenance/run_bot_webhook.py`
   - Бот перестанет использовать getUpdates, конфликта не будет
