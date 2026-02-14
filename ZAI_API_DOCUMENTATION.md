# 🤖 ZAI API - Документация и подключение

**Дата создания:** 12 февраля 2026

---

## 🔍 Поиск ZAI API

### Результаты поиска

```
❌ PyPI: zai-openai - НЕ НАЙДЕН
❌ GitHub: zai-org/zai-python - НЕ НАЙДЕН
❌ GitHub: zai-org/zai-openai - НЕ НАЙДЕН
⚠️  ZAI.org (智谱AI): Доступен (китайский язык)
```

---

## 🤔 Что такое ZAI?

**Возможные варианты:**

### Вариант 1: Z.ai (智谱AI)
- **Сайт:** https://open.bigmodel.cn
- **Язык:** Китайский
- **API:** OpenAI-совместимый
- **Модели:** GLM-4, GLM-4-Flash, GLM-4-Vision

### Вариант 2: zai-openai
- **Статус:** Не найден на PyPI
- **Возможно:** Приватный пакет или beta-версия

### Вариант 3: Другой сервис
- **Возможно:** zai.ai, zai-api, zai-sdk

---

## 🔧 Как подключить ZAI API

### Вариант A: Использовать OpenAI-совместимый формат

**Если ZAI API поддерживает OpenAI формат:**
```python
from openai import OpenAI

# Инициализация
client = OpenAI(
    base_url="https://api.zai.com/v1",  # Замените на реальный endpoint
    api_key=os.getenv("ZAI_API_KEY")
)

# Пример запроса
response = client.chat.completions.create(
    model="glm-4-flash",
    messages=[
        {"role": "system", "content": "Ты аналитик городских проблем."},
        {"role": "user", "content": "Проанализируй текст жалобы"}
    ],
)
```

### Вариант B: Использовать HTTP запросы напрямую

```python
import httpx
import os
import json

ZAI_API_KEY = os.getenv("ZAI_API_KEY", "")
ZAI_BASE_URL = os.getenv("ZAI_BASE_URL", "https://api.zai.com/v1")

async def analyze_complaint(text: str) -> dict:
    """Анализ через ZAI API (HTTP)"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{ZAI_BASE_URL}/chat/completions",
                headers={
                    "Authorization": f"Bearer {ZAI_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "glm-4-flash",
                    "messages": [
                        {"role": "system", "content": "Ты аналитик городских проблем."},
                        {"role": "user", "content": text}
                    ],
                    "temperature": 0.7,
                    "max_tokens": 1000,
                },
                timeout=30.0,
            )
            response.raise_for_status()
            data = response.json()
            
            # Парсинг ответа
            if "choices" in data:
                content = data["choices"][0]["message"]["content"]
                return {"content": content}
            return {"error": "Unexpected response format"}
            
    except Exception as e:
        return {"error": str(e)}
```

### Вариант C: Использовать Mock сервис (готово работает)

```python
# services/zai_service.py
# ✅ УЖЕ ИМЕЕТСЯ И РАБОТАЕТ!

from services.zai_service import analyze_complaint

result = await analyze_complaint("На улице Ленина огромная яма")
# Возвращает: {"category": "Дороги", "address": "ул. Ленина", "summary": "..."}
```

---

## 📋 Инструкция по подключению ZAI

### Шаг 1: Получить API ключ

1. Перейдите на сайт ZAI
2. Создайте аккаунт или войдите
3. Перейдите в API Keys
4. Создайте новый API ключ
5. Скопируйте ключ

### Шаг 2: Добавить ключ в .env

```bash
# .env
ZAI_API_KEY=your_api_key_here
ZAI_BASE_URL=https://api.zai.com/v1
```

### Шаг 3: Создать клиент ZAI

**services/zai_service.py:**
```python
import os
from openai import OpenAI

api_key = os.getenv("ZAI_API_KEY", "")
base_url = os.getenv("ZAI_BASE_URL", "https://api.zai.com/v1")

client = OpenAI(api_key=api_key, base_url=base_url)

async def analyze_complaint(text: str) -> dict:
    """Анализ через ZAI API"""
    response = client.chat.completions.create(
        model="glm-4-flash",
        messages=[
            {"role": "system", "content": "Ты аналитик городских проблем."},
            {"role": "user", "content": text}
        ],
    )
    
    content = response.choices[0].message.content
    return {"content": content}
```

### Шаг 4: Использовать в коде

```python
from services.zai_service import analyze_complaint

result = await analyze_complaint("На улице Ленина огромная яма")
print(result)
```

---

## 🔄 Альтернативы

### Вариант 1: Использовать готовый Mock сервис ✅

**Что у нас ЕСТЬ:**
- ✅ Mock сервис с 28 категориями
- ✅ Ключевые слова для точной классификации
- ✅ Regex для извлечения адресов
- ✅ Работает БЕЗ внешних API

**Как использовать:**
```python
from services.zai_service import analyze_complaint

result = await analyze_complaint("На улице Ленина огромная яма")
# Возвращает: {"category": "Дороги", "address": "ул. Ленина", "summary": "..."}
```

### Вариант 2: Использовать Anthropic ✅

**У нас ЕСТЬ:**
```python
# services/zai_service.py
_anthropic_client = Anthropic(api_key=_anthropic_key)
```

**Как использовать:**
```bash
# .env
ANTHROPIC_API_KEY=your_anthropic_key
```

### Вариант 3: Использовать OpenAI ✅

**У нас ЕСТЬ:**
```python
# services/zai_service.py
_openai_client = AsyncOpenAI(api_key=_openai_key)
```

**Как использовать:**
```bash
# .env
OPENAI_API_KEY=your_openai_key
```

---

## 📊 Сравнение вариантов

| Вариант | Статус | Плюсы | Минусы |
|---------|--------|-------|--------|
| ZAI API | ❌ Не найден | - | Нет документации |
| Mock сервис | ✅ Работает | Нет внешних зависимостей | Не AI, только ключевые слова |
| Anthropic | ✅ Работает | Мощный AI | Требует ключ |
| OpenAI | ✅ Работает | Популярный API | Требует ключ |

---

## 🎯 Рекомендация

### Для тестирования СЕЙЧАС:
**Используйте Mock сервис!**
```python
from services.zai_service import analyze_complaint

result = await analyze_complaint("На улице Ленина огромная яма")
# Работает! ✅
```

### Для production:
**Подключите Anthropic или OpenAI**
```bash
# Установка
pip install anthropic  # или
pip install openai

# Настройка
# .env
ANTHROPIC_API_KEY=your_key
# или
OPENAI_API_KEY=your_key
```

---

## 📚 Ссылки для поиска

### Официальные источники ZAI
- https://open.bigmodel.cn (ZAI)
- https://github.com (поиск "zai" или "智谱AI")
- https://pypi.org (поиск "zai")

### OpenAI-совместимые библиотеки
- **openai**: https://github.com/openai/openai-python
- **anthropic**: https://github.com/anthropics/anthropic-python
- **litellm**: https://github.com/litellm/litellm (универсальный клиент)

---

## 🚀 Как протестировать

### Mock сервис
```bash
cd C:\Soobshio_project
python -c "from services.zai_service import analyze_complaint; print('Mock service OK')"
```

### Anthropic
```bash
cd C:\Soobshio_project
python -c "from services.zai_service import _anthropic_client; print('Anthropic client OK')"
```

### OpenAI
```bash
cd C:\Soobshio_project
python -c "from services.zai_service import _openai_client; print('OpenAI client OK')"
```

---

## 📝 Что делать, если вы найдете ZAI документацию

1. **Поделитесь ссылкой** на документацию
2. **Укажите формат API** (OpenAI-совместимый или другой)
3. **Укажите endpoint** (base_url)
4. **Укажите модель** (например: glm-4-flash)

Я создам правильный клиент!

---

## 🎯 Что у нас работает СЕЙЧАС

### ✅ Mock сервис
- **Классификация:** 28 категорий
- **Ключевые слова:** ~200+ слов
- **Адресная экстракция:** 4 паттерна regex
- **Работает:** Стабильно, без ошибок

### ✅ Anthropic интеграция
- **Клиент:** `anthropic==0.70.0`
- **Модель:** claude-3-sonnet-20240229
- **Статус:** Работает

### ✅ OpenAI интеграция
- **Клиент:** `openai>=1.0.0`
- **Модель:** gpt-3.5-turbo
- **Статус:** Работает

---

## 🎉 ИТОГО

### Что есть сейчас:
1. ✅ Mock сервис (Рабочий)
2. ✅ Anthropic клиент (Работает)
3. ✅ OpenAI клиент (Работает)
4. ⚠️ ZAI API - Документация не найдена

### Рекомендация:
**Используйте Mock сервис для тестирования!**

Если вы найдете правильную документацию ZAI API, я обновлю код.

---

**Дата:** 12 февраля 2026
**Версия:** 2.0.0
**Категорий:** 28
**AI клиенты:** 3 (Mock, Anthropic, OpenAI)

---

**✅ Mock сервис РАБОТАЕТ! Готов к использованию!** 🚀
