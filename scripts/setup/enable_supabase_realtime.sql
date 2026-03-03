-- Включение Supabase Realtime для таблицы reports
-- Выполнить в Supabase Dashboard: SQL Editor → New query → вставить и Run

-- 1. Добавить таблицу в публикацию Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE reports;

-- 2. (Опционально) Включить REPLICA IDENTITY для передачи полных строк при UPDATE/DELETE
ALTER TABLE reports REPLICA IDENTITY FULL;

-- Проверка: в Dashboard → Database → Replication должны быть видны таблицы в publication supabase_realtime.
