# Настройка OpenRouter API

OpenRouter — единственный AI провайдер в проекте. Используются специализированные модели Qwen:
- **qwen/qwen3-coder** — для анализа текста из пабликов (VK, Telegram)
- **qwen/qwen-vl-plus** — для анализа изображений

## Получение API ключа

1. Зарегистрируйтесь на [openrouter.ai](https://openrouter.ai)
2. Перейдите в [Settings → Keys](https://openrouter.ai/keys)
3. Создайте новый API ключ
4. Скопируйте ключ в `.env`:

```bash
OPENROUTER_API_KEY=sk-or-v1-...
```

## Модели

### Для анализа текста (паблики VK/Telegram)
```bash
OPENROUTER_TEXT_MODEL=qwen/qwen3-coder
```
**qwen3-coder** — специализированная модель для анализа кода и структурированных данных, отлично подходит для извлечения категорий и адресов из текста жалоб.

### Для анализа изображений
```bash
OPENROUTER_VISION_MODEL=qwen/qwen-vl-plus
```
**qwen-vl-plus** — vision-модель с поддержкой изображений, определяет категорию проблемы, нарушения парковки, номера авто и т.д.

## Интеграция в проект

OpenRouter используется как единственный AI провайдер:

1. **OpenRouter (qwen3-coder)** — анализ текста
2. **OpenRouter (qwen-vl-plus)** — анализ изображений
3. Keyword fallback — если OpenRouter недоступен

Если Z.AI недоступен, система автоматически попробует OpenRouter с выбранной моделью.

## Мониторинг использования

OpenRouter предоставляет дашборд с статистикой использования:
- https://openrouter.ai/activity

## Стоимость

- Многие модели бесплатны (Llama, Gemini)
- Платные модели оплачиваются по использованию (credits)
- Минимальный депозит не требуется для бесплатных моделей

## Примеры использования

После настройки ключа в `.env`, система автоматически будет использовать OpenRouter при недоступности Z.AI:

```python
from services.zai_service import analyze_complaint

result = await analyze_complaint("На ул. Мира 15 не работает освещение")
print(result["provider"])  # "openrouter:meta-llama/llama-3.1-70b-instruct"
print(result["category"])  # "Освещение"
```
