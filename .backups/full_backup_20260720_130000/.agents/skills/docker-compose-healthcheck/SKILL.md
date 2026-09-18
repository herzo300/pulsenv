---
name: docker-compose-healthcheck
description: Мониторинг, автоматическое восстановление и диагностика 9 Docker-сервисов City Pulse на Timeweb VPS.
---

# Docker Compose Healthcheck Skill

## Назначение
Поддержание непрерывной работы микросервисной архитектуры на сервере (Backend, Nginx, Postgres, Redis, Camera Probe, Viseron NVR, Monitoring, OpenSERP, Tor).

## Диагностика и исправление
1. **Смена IP контейнеров**: Автоматический перезапуск Nginx (`docker compose restart nginx`) при пересборке backend для актуализации DNS-записей.
2. **Проверка логов**: Отслеживание ошибок 502/504, нехватки памяти и обрывов сетевых соединений.
