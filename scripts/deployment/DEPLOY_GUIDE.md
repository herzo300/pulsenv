# Руководство по деплою Cloudflare Worker

## Проблема с деплоем

Если GitHub Actions падает с ошибкой `npx failed with exit code 1`, используйте альтернативные методы ниже.

---

## ✅ Способ 1: Прямой деплой через API (РЕКОМЕНДУЕТСЯ)

**Требования:**
- CF_API_TOKEN в `.env` файле

**Шаги:**

1. Получите API токен:
   - Откройте [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
   - Создайте токен с правами: `Workers:Edit` для вашего аккаунта
   - Или используйте существующий токен из wrangler config

2. Добавьте в `.env`:
   ```env
   CF_API_TOKEN=your_token_here
   CF_ACCOUNT_ID=b55123fb7c25f3c5f38a1dcab5a36fa8
   CF_WORKER_NAME=anthropic-proxy
   ```

3. Запустите деплой:
   ```bash
   py scripts/deployment/deploy_direct.py
   ```

**Преимущества:**
- ✅ Не требует wrangler CLI
- ✅ Не зависит от GitHub Actions
- ✅ Прямой контроль над процессом
- ✅ Видны все ошибки сразу

---

## ✅ Способ 2: Через npx wrangler (без установки)

**Требования:**
- Node.js и npm установлены
- Выполнен `wrangler login` хотя бы раз (или токен в .env)

**Шаги:**

```bash
cd cloudflare-worker
py scripts/deployment/deploy_npx.py
```

Или вручную:
```bash
cd cloudflare-worker
npx wrangler deploy
```

**Преимущества:**
- ✅ Не требует глобальной установки wrangler
- ✅ Использует сохраненные credentials
- ✅ Автоматически скачивает wrangler при первом использовании

---

## ✅ Способ 3: Через wrangler CLI (если установлен)

**Требования:**
- `npm install -g wrangler`
- `wrangler login` выполнен

**Шаги:**

**Windows:**
```powershell
cd cloudflare-worker
.\deploy.ps1
```

**Linux/Mac:**
```bash
cd cloudflare-worker
./deploy.sh
```

**Python (кроссплатформенный):**
```bash
cd cloudflare-worker
py deploy.py
```

---

## ✅ Способ 4: Ручной деплой через Dashboard

**Когда использовать:**
- Все остальные способы не работают
- Нужно быстро задеплоить без настройки

**Шаги:**

1. Откройте [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Выберите **Workers & Pages**
3. Найдите worker `anthropic-proxy`
4. Нажмите **"Edit code"**
5. Скопируйте содержимое `cloudflare-worker/worker.js`
6. Вставьте в редактор
7. Нажмите **"Save and Deploy"**

**Преимущества:**
- ✅ Работает всегда
- ✅ Не требует CLI или скриптов
- ✅ Можно проверить код перед деплоем

---

## ✅ Способ 5: Получение токена из wrangler config

Если вы уже выполняли `wrangler login`, токен сохранен в конфиге:

**Windows:**
```
%APPDATA%\xdg.config\.wrangler\config\default.toml
```

**Linux/Mac:**
```
~/.config/.wrangler/config/default.toml
```

Найдите строку `oauth_token = "..."` и скопируйте значение в `.env` как `CF_API_TOKEN`.

---

## 🔍 Диагностика проблем

### Проблема: "CF_API_TOKEN not found"

**Решение:**
1. Получите токен из Cloudflare Dashboard или wrangler config
2. Добавьте в `.env`: `CF_API_TOKEN=your_token`

### Проблема: "npm not found"

**Решение:**
- Установите Node.js: https://nodejs.org/
- Или используйте `deploy_direct.py` (не требует npm)

### Проблема: "wrangler not found"

**Решение:**
- Используйте `deploy_npx.py` (не требует установки wrangler)
- Или используйте `deploy_direct.py` (не требует wrangler вообще)

### Проблема: "Syntax error in worker.js"

**Решение:**
```bash
cd cloudflare-worker
node -c worker.js
```
Исправьте синтаксические ошибки перед деплоем.

### Проблема: "Worker exceeds 10MB limit"

**Решение:**
- Оптимизируйте код
- Удалите неиспользуемые зависимости
- Минифицируйте JavaScript

---

## 📝 Быстрый старт (Windows)

```powershell
# 1. Добавьте токен в .env
# CF_API_TOKEN=your_token_here

# 2. Запустите прямой деплой
py scripts/deployment/deploy_direct.py
```

---

## 📝 Быстрый старт (если есть Node.js)

```bash
# 1. Перейдите в директорию worker
cd cloudflare-worker

# 2. Деплой через npx
npx wrangler deploy
```

---

## 🔗 Полезные ссылки

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Wrangler CLI Docs](https://developers.cloudflare.com/workers/wrangler/)
- [Cloudflare Dashboard](https://dash.cloudflare.com)
- [API Tokens](https://dash.cloudflare.com/profile/api-tokens)
