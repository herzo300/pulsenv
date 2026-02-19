# Быстрый деплой Cloudflare Worker

## ⚡ Самый быстрый способ (2 минуты)

### Ручной деплой через Dashboard

1. Откройте: https://dash.cloudflare.com
2. **Workers & Pages** → `anthropic-proxy` → **Edit code**
3. Скопируйте весь код из `cloudflare-worker/worker.js`
4. Вставьте в редактор Cloudflare
5. Нажмите **Save and Deploy**
6. Готово! ✅

**Проверка:**
- https://anthropic-proxy.uiredepositionherzo.workers.dev/health

---

## 🔄 Альтернативные способы

### Через npx wrangler (если сеть работает)

```bash
cd cloudflare-worker
npx wrangler deploy
```

### Через Python скрипт (автоматически находит токен)

```bash
py scripts/deployment/deploy_direct.py
```

### Через GitHub Actions

```bash
py scripts/deployment/deploy_now.py
```

---

## 📚 Подробная документация

- [DEPLOY_SOLUTIONS.md](./DEPLOY_SOLUTIONS.md) - Все решения проблем с деплоем
- [DEPLOY_ALTERNATIVES.md](./DEPLOY_ALTERNATIVES.md) - Альтернативные методы
- [scripts/deployment/DEPLOY_GUIDE.md](../scripts/deployment/DEPLOY_GUIDE.md) - Подробное руководство
