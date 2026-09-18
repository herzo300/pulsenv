---
name: git-master
description: "Git-работ流程 для City Pulse: коммиты на русском, ветвление под фичи (main + feature-branches), pre-commit hook с ruff+gitleaks, разрешение merge-конфликтов. Текущая ветка main, коммиты в формате feat:/fix:/chore:."
category: workflow
risk: safe
source: OMC (adapted for City Pulse)
date_added: '2026-07-05'
project: Soobshio_project
---

# Git Master — City Pulse / СообщиО

Git-гигиена для активного проекта с большой историей (8+ коммитов видны, реальная разработка). В репозитории идёт активная чистка (удалено 30+ legacy-файлов в текущем статусе).

## 🎯 Применять когда

- Подготовка коммита (формат сообщения, что включать)
- Ветвление под новую фичу/фикс
- Разрешение merge-конфликтов
- Чистка истории (rebase, squash) — аккуратно!
- Восстановление после ошибочного коммита/push
- Работа с `git status` (там сейчас 60+ изменений — чистка legacy)

## 📋 Текущее состояние репозитория

```
Ветка:        main (основная)
Git user:     herzo300
Изменений:    60+ файлов (M/D/??)
Что происходит: масштабная чистка legacy-скриптов
                (deploy_*.py, debug_*.py, _deploy_now.py и др.)
```

## 🌿 Стратегия ветвления (рекомендуемая для проекта)

```
main              ← стабильный, деплоится на Timeweb
 ├── feature/X    ← новая фича (например feature/gamification-levels)
 ├── fix/X        ← багфикс (fix/jwt-refresh)
 ├── chore/X      ← рефактор/чистка (chore/remove-legacy-scripts)
 └── hotfix/X     ← срочный фикс продакшена
```

**Правила:**
- Не коммитить напрямую в `main` если есть сомнения (создать ветку)
- `feature/*` → PR в main (или merge после ревью)
- `hotfix/*` → fast-track в main при критичной проблеме

## 📝 Формат коммитов проекта

Проект использует **Conventional Commits** (видно из истории):

```
<type>(<scope>): <description в русском или английском>

[опционально body]
```

**Виды (type) из истории проекта:**
- `feat:` — новая фича (`feat: add gamification system`)
- `fix:` — багфикс (`fix: double /api/ prefix bugs in Flutter`)
- `chore:` — рефактор/чистка (`chore: cleanup temp scripts`)
- `docs:` — документация
- `refactor:` — рефакторинг без изменения поведения
- `test:` — тесты
- `ci:` — CI/CD
- `perf:` — производительность

**Scope (опционально):** `feat(gamification):`, `fix(backend):`, `chore(deploy):`

## ✅ Pre-commit checklist (проектный)

Перед каждым коммитом:

```bash
# 1. Линтинг
ruff check .

# 2. Smoke-тесты API (если есть backend-изменения)
python -m pytest tests/test_smoke_api.py -q

# 3. Секреты (gitleaks — настроен .gitleaks.toml)
gitleaks detect --source . --no-banner

# 4. Проверить, что .env не в staging
git status --porcelain | grep -E "\.env$" && echo "❌ .env в коммите!" || echo "✅ OK"

# 5. Проверить, что нет ci_test.db и других артефактов
git status --porcelain | grep -E "\.(db|log|tmp)$" && echo "⚠️ Артефакты в коммите"
```

## 🧹 Текущая чистка legacy (что делать с 60+ изменениями)

В `git status` сейчас массовое удаление legacy-скриптов. Рекомендация:

```bash
# 1. Сгруппировать изменения логически
# Группа A: удаление deploy-скриптов (deploy_*.py, _deploy_now.py, auto_deploy.py)
git add -p  # или явно перечислить файлы
git commit -m "chore(deploy): remove legacy deploy scripts

Удалены устаревшие скрипты авто-деплоя (deploy_to_timeweb.py,
auto_deploy.py, _deploy_now.py и др.). Заменены на docker-compose
+ scripts/deployment/."

# Группа B: удаление debug-скриптов (debug_*.py)
git add debug_*.py diagnostics.py
git commit -m "chore: remove debug scripts (replaced by logs/observability)"

# Группа C: обновление конфигов (docker-compose.yml, .env.example)
git add docker-compose.yml .env.example .env.production.template
git commit -m "chore(config): update docker-compose and env templates"

# Группа D: обновление документации
git add README.md PROJECT_STRUCTURE.md TECHNICAL_DOCUMENTATION.md
git commit -m "docs: update project structure and tech docs"
```

**Правило:** маленькие, атомарные коммиты с понятным `type(scope): description`.

## 🔀 Разрешение merge-конфликтов

```bash
# Стандартный flow
git fetch origin
git merge origin/main
# CONFLICT в файлах...

# 1. Найти конфликты
git status

# 2. Решить в редакторе (поиск <<<<<<< ======= >>>>>>>)

# 3. Проверить, что код работает после разрешения
ruff check <conflicted_file>
python -m pytest tests/ -q

# 4. Mark as resolved
git add <resolved_files>
git commit  # (merge commit) или git rebase --continue
```

**Приоритет при конфликте:**
- Конфиг `core/config.py` — оставлять рабочую версию, проверять env
- Миграции Alembic — сливать обе (не терять изменения)
- `.env.example` — объединять ключи из обеих веток

## 🛠 Восстановление после ошибок

```bash
# Отменить последний коммит (НЕ push'нутый) — сохранить изменения
git reset --soft HEAD~1

# Отменить коммит и изменения (ОПАСНО)
git reset --hard HEAD~1

# Отменить push (если уже ушёл) — создать revert
git revert <commit_sha>
git push origin main

# Случайно закоммитил .env
git rm --cached .env
echo ".env" >> .gitignore
git commit -m "chore: remove .env from tracking"
# ВАЖНО: сменить все секреты! (считаем скомпрометированными)
```

## 📊 Полезные команды для проекта

```bash
# Кто что менял (для ревью)
git log --author="herzo300" --oneline -20

# История конкретного файла
git log --follow services/Backend/app.py

# Что в текущем staging (перед коммитом)
git diff --cached --stat

# Найти, когда была добавлена строка
git log -S "ENABLE_AI_STACK" --oneline

# Сравнить с удалённым main
git diff origin/main...HEAD --stat
```

## 🔐 .gitignore — что должно быть исключено

Проектный `.gitignore` должен включать:
- `.env` (секреты)
- `*.db`, `ci_test.db` (тестовые БД)
- `data/` (runtime данные)
- `logs/` (логи)
- `__pycache__/`, `.venv/`, `.pytest_cache/`
- `.omc/` (состояние OMC)
- `*.tmp`, `default.conf.tmp`

## ✅ Definition of Done для коммита

- [ ] `ruff check .` зелёный
- [ ] `pytest tests/test_smoke_api.py -q` зелёный (если есть backend-правки)
- [ ] `gitleaks detect` — 0 находок
- [ ] Коммит атомарный (одна логическая задача)
- [ ] Сообщение в формате `type(scope): description`
- [ ] Нет случайных файлов (`.env`, `*.db`, артефактов)
- [ ] Если менял миграции — проверил up + down

## 🚫 НЕ применять когда

- Нужен PR с ревью — это к github/workflow скиллам
- Нужно принудительно переписать историю main — ОПАСНО, согласовать с командой
- Конфликты в сгенерированных файлах (миграции кроме head) — отдельный разбор
