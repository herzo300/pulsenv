# Решения проблем с деплоем Cloudflare Worker

## Текущая ситуация

Обнаружены проблемы с деплоем:
1. ❌ GitHub Actions падает с `npx failed with exit code 1`
2. ❌ `npx wrangler deploy` падает с сетевой ошибкой
3. ❌ Прямой деплой через API падает с `ConnectionResetError`

---

## ✅ РЕШЕНИЕ 1: Ручной деплой через Cloudflare Dashboard (САМЫЙ НАДЕЖНЫЙ)

**Когда использовать:** Всегда работает, не зависит от CLI или сетевых проблем.

### Шаги:

1. **Откройте Cloudflare Dashboard:**
   - https://dash.cloudflare.com
   - Войдите в аккаунт

2. **Перейдите в Workers & Pages:**
   - В боковом меню выберите **Workers & Pages**
   - Найдите worker `anthropic-proxy`

3. **Отредактируйте код:**
   - Нажмите на worker `anthropic-proxy`
   - Нажмите **"Edit code"** или **"Quick edit"**

4. **Скопируйте код:**
   - Откройте `cloudflare-worker/worker.js` в редакторе
   - Выделите весь код (Ctrl+A)
   - Скопируйте (Ctrl+C)

5. **Вставьте и задеплойте:**
   - Вставьте код в редактор Cloudflare (Ctrl+V)
   - Нажмите **"Save and Deploy"** или **"Deploy"**

6. **Проверьте:**
   - Откройте: https://anthropic-proxy.uiredepositionherzo.workers.dev/health
   - Должен вернуться `{"status":"ok"}`

**Время:** ~2-3 минуты  
**Надежность:** ⭐⭐⭐⭐⭐ (100%)

---

## ✅ РЕШЕНИЕ 2: Исправить GitHub Actions Workflow

Если хотите использовать автоматический деплой через GitHub Actions:

### Вариант A: Использовать улучшенный workflow

1. Переименуйте текущий workflow:
   ```bash
   mv .github/workflows/deploy-worker.yml .github/workflows/deploy-worker.yml.backup
   ```

2. Используйте улучшенный workflow:
   ```bash
   mv .github/workflows/deploy-worker-improved.yml .github/workflows/deploy-worker.yml
   ```

3. Запустите деплой:
   ```bash
   py scripts/deployment/deploy_now.py
   ```

### Вариант B: Исправить текущий workflow

Откройте `.github/workflows/deploy-worker.yml` и замените на:

```yaml
name: Deploy CF Worker

on:
  push:
    paths:
      - 'cloudflare-worker/worker.js'
      - 'cloudflare-worker/wrangler.toml'
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Wrangler
        run: npm install -g wrangler@latest

      - name: Verify Worker Syntax
        working-directory: cloudflare-worker
        run: |
          node -c worker.js || exit 1

      - name: Deploy Worker
        working-directory: cloudflare-worker
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CF_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: b55123fb7c25f3c5f38a1dcab5a36fa8
        run: |
          wrangler deploy --compatibility-date=2024-01-01
```

---

## ✅ РЕШЕНИЕ 3: Использовать wrangler CLI локально (если сеть работает)

Если у вас есть стабильное интернет-соединение:

1. **Установите wrangler:**
   ```bash
   npm install -g wrangler
   ```

2. **Авторизуйтесь:**
   ```bash
   wrangler login
   ```

3. **Деплой:**
   ```bash
   cd cloudflare-worker
   wrangler deploy
   ```

**Если не работает из-за сетевых проблем:**
- Используйте VPN
- Проверьте настройки прокси
- Используйте РЕШЕНИЕ 1 (ручной деплой)

---

## ✅ РЕШЕНИЕ 4: Использовать Cloudflare API напрямую с прокси

Если нужно автоматизировать, но есть проблемы с сетью:

1. **Настройте прокси в скрипте:**
   - Откройте `scripts/deployment/deploy_direct.py`
   - Добавьте поддержку прокси (аналогично `deploy_now.py`)

2. **Или используйте curl с прокси:**
   ```bash
   curl -X PUT \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/javascript" \
     --data-binary @cloudflare-worker/worker.js \
     https://api.cloudflare.com/client/v4/accounts/ACCOUNT_ID/workers/scripts/anthropic-proxy
   ```

---

## 📊 Сравнение методов

| Метод | Надежность | Скорость | Автоматизация | Требования |
|-------|-----------|----------|---------------|------------|
| **Dashboard (ручной)** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ❌ | Браузер |
| **GitHub Actions** | ⭐⭐⭐ | ⭐⭐⭐ | ✅ | GitHub Secrets |
| **wrangler CLI** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ | npm, сеть |
| **API напрямую** | ⭐⭐ | ⭐⭐⭐⭐ | ✅ | Токен, сеть |

---

## 🎯 Рекомендация

**Для быстрого решения проблемы:**
👉 Используйте **РЕШЕНИЕ 1** (ручной деплой через Dashboard)

**Для долгосрочного решения:**
👉 Исправьте GitHub Actions workflow (РЕШЕНИЕ 2) или используйте wrangler CLI локально (РЕШЕНИЕ 3)

---

## 🔧 Дополнительные скрипты

Созданы следующие скрипты для деплоя:

1. **`scripts/deployment/deploy_direct.py`**
   - Прямой деплой через Cloudflare API
   - Автоматически находит токен из wrangler config
   - Не требует wrangler CLI

2. **`scripts/deployment/deploy_npx.py`**
   - Деплой через `npx wrangler`
   - Не требует глобальной установки wrangler

3. **`scripts/deployment/deploy_now.py`**
   - Обновляет GitHub Secrets и триггерит workflow
   - Использует SOCKS5 прокси для GitHub API

4. **`scripts/deployment/full_update.py`**
   - Полный цикл: деплой Worker + обновление бота

---

## 📝 Быстрая инструкция (копировать)

```
1. Откройте: https://dash.cloudflare.com
2. Workers & Pages → anthropic-proxy → Edit code
3. Скопируйте код из cloudflare-worker/worker.js
4. Вставьте в редактор Cloudflare
5. Save and Deploy
6. Проверьте: https://anthropic-proxy.uiredepositionherzo.workers.dev/health
```

---

## ❓ Частые вопросы

**Q: Почему GitHub Actions падает?**  
A: Возможные причины: проблемы с `npx`, истекший токен, сетевые проблемы. Используйте ручной деплой.

**Q: Можно ли автоматизировать ручной деплой?**  
A: Да, можно использовать Cloudflare API напрямую, но нужен стабильный интернет.

**Q: Как часто нужно деплоить?**  
A: Только при изменении `cloudflare-worker/worker.js` или `wrangler.toml`.

**Q: Что делать если токен истек?**  
A: Создайте новый токен: https://dash.cloudflare.com/profile/api-tokens
