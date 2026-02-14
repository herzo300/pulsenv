# Zai GLM-4.7 Integration

## Основные изменения

### 1. Использование Zai вместо Claude

**Было:**
- Claude 3.5 Haiku через Anthropic API
- Хардкод API ключ

**Стало:**
- Zai GLM-4.7 (или GLM-4.7-flash) через Zai API
- API ключ из .env

### 2. Архитектура AI

```
┌─────────────────┐
│   Application    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│  Zai GLM-4.7 (Основной AI)  │
│  - Анализ текста             │
│  - Категоризация             │
│  - Извлечение адреса         │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  Nominatim (Geocoding)       │
│  - Адрес → координаты        │
│  - OpenStreetMap             │
└─────────────────────────────┘
```

### 3. Где используется Zai

| Модуль | Функция |
|--------|---------|
| `services/zai_service.py` | Основной AI анализ |
| `services/ai_service.py` | Обёртка для backward compatibility |
| `services/telegram_parser.py` | AI анализ сообщений из Telegram |
| `core/geoparse.py` | Анализ + геокодинг |
| `main.py` | /ai/analyze endpoint |

## Установка

```bash
pip install zai-openai
```

## Настройка .env

```env
# Zai GLM-4.7 API
ZAI_API_KEY=zai-xxxxx
```

## API Endpoints

### /ai/analyze
Анализ текста через Zai

```bash
curl -X POST http://127.0.0.1:8000/ai/analyze \
  -H "Content-Type: application/json" \
  -d '{"text": "Яма на Ленина 15"}'
```

Ответ:
```json
{
  "category": "ул Ленина 15",
  "address": null,
  "summary": "яма на Ленина 15"
}
```

## Код в проекте

### services/zai_service.py
```python
from zai_openai import ZaiClient

_api_key = os.getenv("ZAI_API_KEY", "")
client = ZaiClient(api_key=_api_key) if _api_key else None

async def analyze_complaint(text: str) -> Dict[str, Any]:
    # GLM-4.7 анализ текста
    response = client.chat.completions.create(
        model="glm-4.7-flash",
        messages=[...],
        temperature=0.1,
        max_tokens=300
    )
    return json.loads(response.choices[0].message.content)
```

### core/geoparse.py
```python
async def claude_geoparse(text: str) -> Tuple[float, float, str]:
    # Zai анализирует текст
    ai_result = await analyze_complaint(text)
    category = ai_result.get('category', 'Нижневартовск центр')

    # Nominatim геокодинг
    lat, lng = await nominatim_geocode(category)
    return lat, lng, category
```

### services/telegram_parser.py
```python
async def analyze_complaint(text: str) -> dict:
    # Используем Zai через services/zai_service
    from services.zai_service import analyze_complaint as zai_analyze
    result = await zai_analyze(text)
    return result
```

## Аргументы модели

| Аргумент | Значение | Описание |
|----------|----------|----------|
| `model` | `glm-4.7` | Основная модель |
| `temperature` | `0.1` | Низкая температура для предсказуемости |
| `max_tokens` | `300` | Максимум токенов в ответе |
| `system` | "Senior Python Engineer" | Роль AI |

## Fallback механизмы

Если Zai недоступен:

1. **services/zai_service.py**
   - Возвращает fallback: `{"category": "Прочее", ...}`

2. **core/geoparse.py**
   - Использует координаты центра Нижневартовска: `61.034, 76.553`

3. **telegram_parser.py**
   - Логирует ошибку и возвращает базовый результат

## Категории

19 категорий:
- ЖКХ, Дороги, Благоустройство, Транспорт, Экология
- Животные, Торговля, Безопасность, Снег/Наледь, Освещение
- Медицина, Образование, Связь, Строительство, Парковки
- Социальная сфера, Трудовое право, Прочее, ЧП

## Преимущества Zai

1. **Скорость**: GLM-4.7-flash работает быстрее Claude
2. **Цена**: Может быть дешевле Anthropic
3. **API**: Более простой синтаксис (аналог OpenAI)
4. **Контекст**: Отлично работает с длинными текстами

## Логирование

```python
# Telegram parser
logger.info(f"Zai analysis: {result}")

# Services
print(f"Zai error: {e}")
```

## TODO

- [ ] Тестирование с реальным API ключом
- [ ] Добавить метрики использования
- [ ] Добавить кэширование ответов
- [ ] Настроить логирование в файл
