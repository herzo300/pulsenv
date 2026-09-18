---
name: fastapi-security-audit
description: Комплексная проверка безопасности роутеров FastAPI, JWT-аутентификации, валидации Pydantic и CORS-политик.
---

# FastAPI Security Audit Skill

## Назначение
Обеспечение безопасности API бэкенда City Pulse (17 роутеров), предотвращение утечек данных пользователей и защита Webhook.

## Чек-лист безопасности
1. **JWT & Auth**: Валидация подписей токенов, проверка хэширования паролей Argon2/Bcrypt.
2. **Rate Limiting**: Ограничение количества запросов к VLM/ИИ эндпоинтам.
3. **CORS & Headers**: Настройка заголовков HSTS, CSP, X-Frame-Options и X-Content-Type-Options.
