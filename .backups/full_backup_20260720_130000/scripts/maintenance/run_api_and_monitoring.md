# Запуск API и мониторинга для проверки карты на реальных данных

## Быстрый старт

1. **Терминал 1 — API:**
   ```bash
   py main.py
   ```
   Если порт 8000 занят: `set PORT=8001 && py main.py`

2. **Терминал 2 — мониторинг (Telegram + VK → БД + Firebase):**
   ```bash
   py start_all_monitoring.py
   ```
   Мониторинг подключается к 8 каналам Telegram и 8 пабликам VK, обрабатывает сообщения через AI, сохраняет в `soobshio.db` и пушит в Firebase. Карта получает данные из API (`/api/reports`) или из Firebase (через воркер).

3. **Проверка API и карты:**
   ```bash
   py scripts/tests/test_map_and_services.py
   ```
   Если API на 8001: `set PORT=8001 && py scripts/tests/test_map_and_services.py`

4. **Карта в браузере (Flutter):**
   ```bash
   cd services/Frontend && flutter run -d chrome
   ```
   Данные подтягиваются с `http://127.0.0.1:8000/api/reports` (или с Firebase через прокси, если настроен воркер).

## Альтернатива: все сервисы разом

- **Бот + мониторинг + категоризатор** (в отдельных окнах):
  ```bash
  py scripts/maintenance/run_all_services.py
  ```
- **API** нужно запускать отдельно в своём терминале: `py main.py`.

## Если тест выдаёт BadStatusLine

Возможен перехват локальных запросов прокси/VPN. Попробуйте:
- Отключить системный прокси для 127.0.0.1.
- Запускать тест из терминала без `HTTP_PROXY`/`HTTPS_PROXY`.
- Запустить API на свободном порту: `set PORT=8001 && py main.py`, затем `set PORT=8001 && py scripts/tests/test_map_and_services.py`.
