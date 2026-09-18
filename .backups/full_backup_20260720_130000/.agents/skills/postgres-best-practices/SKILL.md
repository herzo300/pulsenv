---
name: postgres-best-practices
description: "Оптимизация PostgreSQL 16 для проекта City Pulse. Индексы, RLS, пулинг соединений, миграции Alembic. Таблицы: reports, users, user_gamification, daily_digest, geo_subscriptions. Продакшн — asyncpg, дев — SQLite."
category: database
risk: safe
source: Supabase community (adapted for City Pulse)
date_added: '2026-07-05'
project: Soobshio_project
---

# PostgreSQL Best Practices — City Pulse / СообщиО

Оптимизация и проектирование PostgreSQL для городской системы мониторинга жалоб Нижневартовска.

## 🎯 Применять когда

- Проектирование/изменение схемы БД (`alembic/versions/`)
- Оптимизация запросов к таблицам `reports`, `users`, `camera_metrics`
- Настройка RLS или индексов для гео-данных (координаты инцидентов)
- Конфигурация пулинга соединений в Docker (сервис `postgres` в docker-compose.yml)
- Проблемы с N+1 запросами в роутерах FastAPI

## 🗄 Стек БД проекта

| Окружение | БД | Драйвер | Назначение |
|-----------|-----|---------|------------|
| Production | PostgreSQL 16 | asyncpg (async) | Docker-контейнер `postgres` |
| Development | SQLite | aiosqlite | `ci_test.db`, быстрые тесты |
| Кэш/очереди | Redis 7.4 | — | Docker-контейнер `redis` |

## 📋 Ключевые таблицы проекта

```sql
-- Основные сущности (см. alembic/versions/ для актуальной схемы)
reports              -- жалобы: координаты, категория, verification_score, статус
users                -- профили пользователей мобильного приложения
user_gamification    -- XP, уровни, достижения (геймификация)
user_achievements    -- выданные достижения
user_quests          -- квесты пользователя
city_memes           -- мемы (контентная часть)
camera_metrics       -- состояние городских камер (online/offline)
gamification_stats   -- агрегированная статистика
daily_digest         -- ежедневный AI-анализ событий города
geo_subscriptions    -- push-подписки по геозонам
```

## ⚡ Приоритетные правила оптимизации

### 1. Производительность запросов (CRITICAL)

```sql
-- Гео-запросы к reports: GiST-индекс на координаты
CREATE INDEX IF NOT EXISTS idx_reports_coords 
ON reports USING GIST (geom);

-- Фильтр по категории + статусу (частый кейс в роутере /complaints)
CREATE INDEX IF NOT EXISTS idx_reports_cat_status 
ON reports (category, status) 
WHERE status IN ('open', 'verified');

-- Partial index для активных жалоб
CREATE INDEX IF NOT EXISTS idx_reports_active 
ON reports (created_at DESC) 
WHERE status != 'closed';
```

### 2. Управление соединениями (CRITICAL)

```python
# core/config.py + services/Backend/app.py
# asyncpg с пулингом для асинхронного FastAPI
DATABASE_URL = "postgresql+asyncpg://user:pass@postgres:5432/citypulse"
# Pool size настраивается в docker-compose.yml (сервис postgres)
```

```yaml
# docker-compose.yml — лимиты соединений
postgres:
  environment:
    POSTGRES_MAX_CONNECTIONS: 100
  # application_name для трассировки
  command: postgres -c log_connections=on -c log_disconnections=on
```

### 3. Безопасность & RLS

```sql
-- RLS для пользовательских данных (многотомантность не нужна, 
-- но разделение ролей admin/user — обязательно)
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY reports_user_policy ON reports
  FOR SELECT USING (user_id = current_setting('app.user_id')::int OR is_public = true);
```

### 4. Дизайн схемы для гео-данных

```sql
-- reports.geom — тип geography(Point, 4326) для геокодированных адресов
-- Адрес: "ул. Ленина, 15" → ST_SetSRID(ST_MakePoint(lon, lat), 4326)
-- Запрос «ближайшие инциденты»:
SELECT id, address, category,
  ST_Distance(geom, ST_MakePoint(76.58, 60.93)::geography) AS dist
FROM reports
WHERE ST_DWithin(geom, ST_MakePoint(76.58, 60.93)::geography, 1000)
ORDER BY dist LIMIT 20;
```

## 🔄 Миграции Alembic (проектный workflow)

```bash
# Создать миграцию после изменения модели
docker compose exec backend alembic revision --autogenerate -m "add X to reports"

# Применить в production
docker compose exec backend alembic upgrade head

# Откат
docker compose exec backend alembic downgrade -1

# ВАЖНО: DB_AUTO_CREATE=false в production после первого alembic upgrade head
```

## 📊 Диагностика (monitor-правила)

```sql
-- Медленные запросы
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC LIMIT 10;

-- Незавершённые транзакции (блокировки)
SELECT pid, state, wait_event_type, query 
FROM pg_stat_activity 
WHERE state != 'idle';

-- Размер таблиц (для роста reports)
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

## ✅ Чек-лист ревью БД-изменений

- [ ] Миграция Alembic создана и протестирована (up + down)
- [ ] Индексы добавлены для новых столбцов в WHERE/ORDER BY
- [ ] N+1 запросов нет (использовать `selectinload`/`joinedload` в SQLAlchemy)
- [ ] Нет `SELECT *` в продакшн-запросах
- [ ] Гео-запросы используют GiST-индекс и `ST_DWithin`
- [ ] `DB_AUTO_CREATE=false` в production `.env`
- [ ] Backup проверен (pg_dump в scripts/maintenance/)

## 🚫 НЕ применять когда

- Нужен Redis-специфичная оптимизация (используй docker-expert +FastAPI)
- Задача по SQLite для тестов — там своя специфика
- Нужна миграция на другую СУБД → отдельная задача
