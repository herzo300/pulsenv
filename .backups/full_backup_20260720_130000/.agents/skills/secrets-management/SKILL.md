---
name: secrets-management
description: "Управление секретами City Pulse: .env с JWT_SECRET/TG_BOT_TOKEN/POSTGRES_PASSWORD, .env.production.template, .gitleaks.toml, .gitignore. Деплой на Timeweb Cloud через scripts/set_secrets.py и scripts/full_merge_secrets.py."
category: security
risk: safe
source: community (adapted for City Pulse)
date_added: '2026-07-05'
project: Soobshio_project
---

# Secrets Management — City Pulse / СообщиО

Безопасное управление секретами для городской системы. Проект уже имеет базовую инфраструктуру (`.gitleaks.toml`, `.gitignore`, `.env.production.template`), нужно её последовательно применять.

## 🎯 Применять когда

- Добавление нового секрета в проект (новый API-ключ, токен, пароль)
- Подготовка `.env` для нового окружения (dev/staging/prod)
- Деплой на Timeweb: `scripts/set_secrets.py`, `scripts/full_merge_secrets.py`
- Аудит на утечки секретов (`gitleaks`)
- Ротация существующих секретов

## 🔑 Реестр секретов проекта

| Секрет | Назначение | Где хранится | Источник ротации |
|--------|------------|--------------|------------------|
| `JWT_SECRET` | Подпись JWT-токенов | `.env` | Генерируется: `openssl rand -hex 32` |
| `TG_BOT_TOKEN` | Telegram бот @monitornv | `.env` | @BotFather |
| `POSTGRES_PASSWORD` | Пароль БД | `.env` | Генерируется |
| `REDIS_PASSWORD` | Пароль Redis | `.env` | Генерируется |
| `DATABASE_URL` | Строка подключения (включает пароль) | `.env` | Производный |
| `PUBLIC_API_BASE_URL` | Базовый URL API | `.env` | Фиксируется при деплое |
| `VISERON_WEBHOOK_TOKEN` | Секрет webhook NVR | `.env` | Генерируется |
| Ключи Z.AI | AI-провайдер | `.env` | Личный кабинет Z.AI |
| Ключи OpenRouter/Gemini | AI-провайдеры (fallback) | `.env` | Их консоли |

## 📂 Файлы проекта

| Файл | Назначение | В git? |
|------|------------|--------|
| `.env` | Реальные секреты (текущее окружение) | ❌ НЕТ |
| `.env.example` | Шаблон с placeholder'ами | ✅ да |
| `.env.production.template` | Шаблон для production | ✅ да |
| `.gitignore` | Исключает `.env`, `*.db`, `data/`, `logs/` | ✅ да |
| `.gitleaks.toml` | Правила сканирования утечек | ✅ да |
| `scripts/set_secrets.py` | Установка секретов на Timeweb VPS | ✅ да |
| `scripts/full_merge_secrets.py` | Слияние секретов из нескольких источников | ✅ да |

## 🛡 Правила проекта (STRICT)

1. **НИКОГДА** не коммитить `.env` (он в `.gitignore`, но проверять)
2. **НИКОГДА** не хардкодить секреты в коде — только через `core/config.py`
3. **ВСЕ** новые секреты добавлять в `.env.example` как `KEY=placeholder`
4. **ВСЕГДА** проверять перед push: `gitleaks detect --source .`
5. Разные секреты для dev / staging / production
6. Логирование маскирует секреты (`***`, `JWT_SECRET=***`)
7. В Docker-образ — только runtime env, не в слоях

## 📝 Стандартный workflow добавления секрета

### 1. Обновить шаблоны

```bash
# .env.example — добавить с placeholder
NEW_API_KEY=your_api_key_here

# .env.production.template — добавить с описанием
NEW_API_KEY=  # Получить: https://provider.example.com/api-keys
```

### 2. В коде — через Pydantic Settings

```python
# core/config.py
class Settings(BaseSettings):
    new_api_key: str | None = None  # опциональный
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
```

### 3. Обновить .gitleaks.toml при нестандартном паттерне

```toml
# .gitleaks.toml
[[rules]]
id = "citypulse-new-api-key"
description = "New API key"
regex = '''NEW_API_KEY\s*=\s*['"]?[a-f0-9]{32}['"]?'''
tags = ["citypulse", "api-key"]
```

### 4. Установить на Timeweb

```bash
# scripts/set_secrets.py — обновить при необходимости
python scripts/set_secrets.py
# Или вручную через SSH на VPS (см. ops/timeweb/README.md)
```

### 5. Проверить

```bash
# Сканирование на утечки
gitleaks detect --source . --no-banner -v

# Проверить, что .env не закоммичен
git ls-files | grep -E "^\.env$" && echo "❌ ОПАСНО" || echo "✅ OK"

# Проверить историю git на случайные коммиты
gitleaks detect --source . --log-opts="--all"
```

## 🔄 Ротация секретов

### JWT_SECRET (критично — инвалидирует все сессии)

```bash
# 1. Сгенерировать новый
openssl rand -hex 32

# 2. Обновить .env на Timeweb
# 3. Перезапустить backend
docker compose restart backend
# 4. Все пользователи будут разлогинены (приемлемо при компрометации)
```

### POSTGRES_PASSWORD

```bash
# 1. Сгенерировать
openssl rand -base64 24

# 2. ALTER USER в PostgreSQL
docker compose exec postgres psql -U citypulse -c \
  "ALTER USER citypulse PASSWORD 'new_password';"

# 3. Обновить DATABASE_URL и POSTGRES_PASSWORD в .env
# 4. Перезапустить backend
```

### TG_BOT_TOKEN

```bash
# 1. Через @BotFather → /revoke
# 2. Получить новый токен
# 3. Обновить TG_BOT_TOKEN в .env
# 4. Перезапустить monitoring + backend
```

## 🔍 Сканирование на утечки

```bash
# Установить gitleaks (если нет)
# Windows (scoop): scoop install gitleaks
# Или через CI: см. .github/workflows/ (если есть gitleaks action)

# Проверка текущего состояния
gitleaks detect --source . --no-banner

# Проверка всей истории git
gitleaks detect --source . --log-opts="--all" --report-path leaks.json

# Если найдена утечка в истории — git filter-repo или BFG
```

## ✅ Чек-лист перед каждым деплоем

- [ ] `gitleaks detect --source .` — 0 находок
- [ ] `git ls-files | grep -E "^\.env$"` — пусто
- [ ] `.env.example` обновлён при новых секретах
- [ ] `core/config.py` читает новые переменные
- [ ] Логи не содержат значений секретов (только masked)
- [ ] `scripts/set_secrets.py` актуален для нового секрета
- [ ] Backup `.env` хранится в защищённом месте (не в git)

## 📋 CI/CD проверки

```yaml
# .github/workflows/ — должно быть (или добавить):
# - gitleaks-action на каждый PR/push
# - pip-audit для зависимостей
# - проверка, что .env не в diff
```

## 🚫 НЕ применять когда

- Нужен активный пентест → security-audit
- Нужна настройка Docker-секретов (Docker secrets/Swarm) — проект на docker compose с env
- Управление секретами в Kubernetes — не применяется (проект не на k8s)
