---
name: security-audit
description: "Аудит безопасности City Pulse: JWT-аутентификация (backend/auth.py), API на FastAPI (17 роутеров), webhook Viseron, city-камеры, PII жителей. Защита JWT_SECRET, PUBLIC_API_BASE_URL, проверка зависимостей, OWASP Top 10 для API."
category: security
risk: safe
source: personal (adapted for City Pulse)
date_added: '2026-07-05'
project: Soobshio_project
---

# Security Audit — City Pulse / СообщиО

Аудит безопасности системы мониторинга городской среды. Обрабатывает жалобы жителей, фото, геолокацию — это PII, требующая защиты. Публичный API + webhook от внешних сервисов (Viseron).

## 🎯 Применять когда

- Аудит безопасности API-эндпоинтов (FastAPI, 17 роутеров)
- Проверка JWT-аутентификации (`backend/auth.py`, `JWT_SECRET`)
- Аудит webhook Viseron (`/api/nvr/viseron/webhook`, токен `VISERON_WEBHOOK_TOKEN`)
- Защита PII жителей (тексты жалоб, фото, адреса, геолокация)
- Проверка зависимостей (`requirements.txt`)
- Подготовка к релизу / деплою на Timeweb

## 🔑 Критичные секреты проекта

| Переменная | Где | Риск при утечке |
|------------|-----|-----------------|
| `JWT_SECRET` | `.env` | Подделка любых токенов пользователей |
| `TG_BOT_TOKEN` | `.env` | Перехват управления ботом @monitornv |
| `POSTGRES_PASSWORD` | `.env` | Полный доступ к БД жителей |
| `REDIS_PASSWORD` | `.env` | Доступ к кэшу/очередям |
| `VISERON_WEBHOOK_TOKEN` | `.env` | Спуфинг webhook от NVR |
| Ключи Z.AI/LLM | `.env` | Списание баланса AI-провайдера |

## 🛡 Фазы аудита для City Pulse

### Фаза 1: Recon (что экспонировано)

```bash
# Публичные эндпоинты (без auth)
curl https://api.city-pulse.ru/openapi.json | jq '.paths | keys'

# Какие порты торчат наружу (должны быть только 80, 443)
docker compose ps --format "table {{.Name}}\t{{.Ports}}"

# Проверить .gitignore на секреты
git ls-files | xargs grep -l "password\|secret\|token" 2>/dev/null | head
```

### Фаза 2: Dependency scan

```bash
# Python-зависимости
pip-audit -r requirements.txt
# или
safety check -r requirements.txt

# gitleaks — уже настроен (.gitleaks.toml)
gitleaks detect --source . --no-banner
```

### Фаза 3: API Security (OWASP API Top 10)

| Риск | Где проверить в City Pulse | Чек |
|------|----------------------------|-----|
| API1: Broken Object Authz | `/complaints/{id}`, `/profile/{user_id}` | IDOR — может ли user A читать жалобу user B? |
| API2: Broken Auth | `backend/auth.py`, JWT | Алгоритм `HS256`, срок жизни токена, refresh |
| API3: Excessive Data | `/admin/metrics` | Возвращает ли админ-эндпоинт PII без auth? |
| API4: Unrestricted Resources | Все эндпоинты | Rate limiting? |
| API5: Broken Function Authz | `/admin/*` | Проверка роли admin? |
| API6: SSRF | Viseron webhook, AI-вызовы | URL-валидация? |
| API7: Security Misconfig | CORS, Nginx | `*` origins? |
| API8: Code Injection | Любой ввод пользователя | SQLi через фильтры? |
| API9: Inventory | Старые роутеры | `backend/` legacy vs `services/Backend/` |

### Фаза 4: Webhook Viseron

```python
# /api/nvr/viseron/webhook — проверка токена
@router.post("/nvr/viseron/webhook")
async def viseron_webhook(req: Request):
    token = req.headers.get("X-Viseron-Token")
    if token != settings.viseron_webhook_token:
        raise HTTPException(403, "Invalid webhook token")
    # Также: проверка source IP (Viseron — внутренний контейнер)
    # Таймаут на payload, лимит размера
```

### Фаза 5: PII и данные жителей

- Тексты жалоб — PII (могут содержать имена, телефоны)
- Фото — могут содержать лица, номера машин
- Адреса + геолокация — местонахождение жителей
- `verification_score` — оценка ИИ (может быть необъективной)

**Правила проекта:**
- Не логировать полные тексты жалоб в prod (только id/hash)
- Фото в приватном хранилище, не в `public/`
- `users` таблица — минимальные данные, без лишних PII

### Фаза 6: Hardening

```python
# JWT в backend/auth.py — проверить:
# - алгоритм HS256 (или RS256 с приватным ключом в секрете)
# - срок жизни access token: 15-60 мин
# - refresh token: ротация
# - проверка на отозванные (blacklist в Redis)

# CORS в services/Backend/app.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://city-pulse.example.ru"],  # НЕ "*"
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

# Rate limiting (медленный Fitz, без него TG/VK скрапинг и AI — уязвимы)
# Добавить slowapi или nginx limit_req
```

### Фаза 7: Docker/infra

- [ ] Контейнеры запускаются от non-root (USER 1001)
- [ ] `postgres` не торчит наружу (только internal network)
- [ ] `redis` требует пароль
- [ ] Образы сканируются (trivy/grype): `trivy image citypulse-backend:latest`
- [ ] `.env` не попадает в образ (только runtime env)

## ✅ Чек-лист перед деплоем на Timeweb

- [ ] `gitleaks detect` — 0 находок
- [ ] `pip-audit` — 0 критических CVE
- [ ] Все эндпоинты с PII — за JWT
- [ ] `/admin/*` — проверка роли
- [ ] Webhook Viseron — проверка токена + IP whitelist
- [ ] CORS — явные origin, не `*`
- [ ] Rate limiting на AI-эндпоинтах (`/ai`, `/vlm`)
- [ ] Логи не содержат секретов и PII
- [ ] HTTPS форсирован (Nginx, HSTS)
- [ ] Backup БД зашифрован

## 📋 Compliance (для городской системы)

- **152-ФЗ «О персональных данных»** — жалобы жителей могут содержать ПДн
- Согласие пользователя — `public/user_agreement.html`, `public/privacy_policy.html`
- Хранение ПДн — на серверах в РФ (Timeweb — российский провайдер ✅)
- См. `docs/LEGAL_COMPLIANCE_CHECKLIST.md`

## 🚫 НЕ применять когда

- Нужен активный пентест продакшена без авторизации — сначала согласовать
- Нужна настройка именно секретов в CI → secrets-management
- Это фаззинг/DoS — не для этого навыка
