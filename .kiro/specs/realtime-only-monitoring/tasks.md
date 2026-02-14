# Implementation Plan: Realtime-Only Monitoring

## Overview

Добавление класса `RealtimeGuard` и его интеграция в три файла мониторинга для фильтрации старых сообщений по таймстемпу и дедупликации по ID.

## Tasks

- [x] 1. Создать модуль `services/realtime_guard.py` с классом `RealtimeGuard`
  - [x] 1.1 Реализовать класс `RealtimeGuard` с `__init__`, `is_new_message`, `is_duplicate`, `mark_processed`, свойствами `startup_time` и `stats`
    - Использовать `OrderedDict` для FIFO-очистки при превышении `_max_size` (10000) до `_trim_size` (5000)
    - Ключ: кортеж `(source: str, message_id: int)`
    - `is_new_message(timestamp)` — возвращает `True` если `timestamp >= _startup_time`
    - Если `timestamp` равен `None` — считать сообщение новым, записать warning в лог
    - `_stats` — dataclass `GuardStats` с полями `skipped_old`, `skipped_duplicate`, `processed_count`
    - _Requirements: 1.1, 2.1, 2.2, 3.1, 3.2, 3.3, 3.4_

  - [x]* 1.2 Написать property-тест: корректность фильтрации по таймстемпу
    - **Property 1: Корректность фильтрации по таймстемпу**
    - Генерировать случайные `startup_time` и `msg_time` через `hypothesis.strategies.datetimes()`
    - Проверить: `is_new_message(msg_time)` возвращает `True` iff `msg_time >= startup_time`
    - Минимум 100 итераций
    - **Validates: Requirements 2.1, 2.2, 4.1, 4.2**

  - [x]* 1.3 Написать property-тест: раунд-трип дедупликации
    - **Property 2: Раунд-трип дедупликации (mark → detect)**
    - Генерировать случайные `source` и `message_id` через `hypothesis.strategies.text()` и `integers()`
    - Вызвать `mark_processed(source, message_id)`, затем проверить `is_duplicate(source, message_id) == True`
    - Минимум 100 итераций
    - **Validates: Requirements 3.2, 3.3**

  - [x]* 1.4 Написать property-тест: инвариант размера множества
    - **Property 3: Инвариант размера множества обработанных**
    - Генерировать список `(source, message_id)` пар длиной 0–20000
    - После каждого `mark_processed` проверить `len(guard._processed_ids) <= max_size`
    - Минимум 100 итераций
    - **Validates: Requirements 3.4**

  - [x]* 1.5 Написать unit-тесты для edge-кейсов `RealtimeGuard`
    - Сообщение ровно в момент запуска — принято
    - Сообщение на 1 секунду раньше — отклонено
    - Дубликат с тем же `(source, id)` — обнаружен
    - Разные `source` с одинаковым `id` — не дубликат
    - `timestamp=None` — сообщение считается новым
    - Статистика корректно инкрементируется
    - _Requirements: 2.1, 2.2, 3.2, 3.3, 3.4_

- [x] 2. Checkpoint — убедиться что все тесты проходят
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Интегрировать `RealtimeGuard` в `start_monitoring.py`
  - [x] 3.1 Добавить создание `RealtimeGuard` в функцию `main()` до регистрации обработчиков
    - Импортировать `RealtimeGuard` из `services.realtime_guard`
    - Создать экземпляр `guard = RealtimeGuard()`
    - Залогировать `guard.startup_time` в формате ISO 8601
    - _Requirements: 1.1, 1.2_

  - [x] 3.2 Добавить проверки в обработчик `handler(event)` внутри `main()`
    - Проверка таймстемпа: `guard.is_new_message(event.message.date)` — если `False`, лог и return
    - Проверка дубликата: `guard.is_duplicate(source, event.message.id)` — если `True`, лог и return
    - После успешной обработки: `guard.mark_processed(source, event.message.id)`
    - Добавить `guard.stats` в периодическую статистику
    - _Requirements: 2.1, 2.2, 3.2, 3.3, 5.1, 5.2, 5.3_

- [x] 4. Интегрировать `RealtimeGuard` в `start_all_monitoring.py`
  - [x] 4.1 Добавить создание `RealtimeGuard` в функцию `main()` до регистрации обработчиков
    - Аналогично 3.1
    - _Requirements: 1.1, 1.2_

  - [x] 4.2 Добавить проверки в `handle_telegram_message(client, event)`
    - Передать `guard` как параметр или использовать глобальную переменную модуля
    - Проверка таймстемпа и дубликата аналогично 3.2
    - _Requirements: 2.1, 2.2, 3.2, 3.3, 5.1, 5.2_

  - [x] 4.3 Передать `guard.startup_time` в VK-поллер
    - Передать `startup_time` в вызов `poll_all_groups()` как параметр
    - _Requirements: 4.1, 4.2_

- [x] 5. Добавить фильтрацию по таймстемпу в `services/vk_monitor_service.py`
  - [x] 5.1 Добавить параметр `startup_time` в функцию `poll_all_groups()`
    - Добавить параметр `startup_time: Optional[datetime] = None`
    - В цикле обработки постов: если `startup_time` задан и `post_date < startup_time` — пропустить пост с логом
    - Обновить `vk_stats` — добавить счётчик `filtered_old`
    - _Requirements: 4.1, 4.2, 5.1_

- [x] 6. Final checkpoint — убедиться что все тесты проходят
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Задачи с `*` — опциональные (тесты), можно пропустить для быстрого MVP
- Каждая задача ссылается на конкретные требования для трассируемости
- Property-тесты используют библиотеку Hypothesis
- `RealtimeGuard` — единственный новый файл; остальные изменения — интеграция в существующий код
