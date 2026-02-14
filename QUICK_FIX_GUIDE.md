# 🚀 Быстрое руководство по исправлениям

## ✅ Что уже исправлено

1. **Cluster Service** - исправлен баг с `min_cluster_size < 2`
2. **Все зависимости** - установлены и работают
3. **База данных** - создана и работает
4. **API** - запускается без ошибок

---

## 🔧 Что нужно исправить

### 1. Telegram мониторинг (требует авторизации)

**Проблема:** Telegram API требует авторизации

**Решение:**
```bash
# Запустить скрипт авторизации
py -c "from telethon import TelegramClient; import os; client = TelegramClient('soobshio_monitor', int(os.getenv('TG_API_ID')), os.getenv('TG_API_HASH')); client.start(phone=os.getenv('TG_PHONE'))"
```

**Или:** Использовать существующую сессию из `tests/test_session.session`

---

### 2. NVD Service (опционально)

**Проблема:** API может быть недоступен

**Решение:** Добавить fallback в `services/nvd_service.py`:
```python
async def get_vulnerabilities(limit: int = 20):
    try:
        # Попытка получить данные
        return await get_data(params={"limit": limit})
    except Exception as e:
        # Fallback на mock данные
        return {
            "success": True,
            "vulnerabilities": [],
            "error": "API unavailable, using mock data"
        }
```

---

### 3. Flutter приложение (требует тестирования)

**Проблема:** Flutter SDK не установлен

**Решение:**
1. Скачать Flutter SDK: https://flutter.dev/docs/get-started/install/windows
2. Добавить в PATH
3. Запустить:
```bash
cd lib
flutter pub get
flutter run -d chrome
```

---

## 📋 Чек-лист перед запуском

- [x] Python 3.14.3 установлен
- [x] Зависимости установлены (`pip install -r requirements.txt`)
- [x] База данных создана (`soobshio.db`)
- [x] `.env` файл настроен
- [x] API запускается (`py -m uvicorn main:app`)
- [ ] Telegram авторизован
- [ ] Flutter SDK установлен
- [ ] Тесты пройдены

---

## 🎯 Команды для быстрого старта

### Запуск API
```bash
py -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

### Проверка здоровья
```bash
py -c "import httpx; print(httpx.get('http://127.0.0.1:8000/health').json())"
```

### Тест AI анализа
```bash
py -c "import httpx; print(httpx.post('http://127.0.0.1:8000/ai/analyze', json={'text': 'Яма на Ленина 15'}).json())"
```

### Проверка базы данных
```bash
py -c "from backend.database import SessionLocal; from backend.models import Report; db = SessionLocal(); print(f'Reports: {db.query(Report).count()}'); db.close()"
```

---

## 🐛 Известные проблемы и решения

### Проблема: "Min cluster size must be greater than one"
**Статус:** ✅ Исправлено
**Решение:** Обновлен `services/cluster_service.py`

### Проблема: Python не найден
**Решение:** Использовать `py` вместо `python`

### Проблема: Telegram не авторизован
**Решение:** Запустить авторизацию (см. выше)

---

## 📞 Контакты для поддержки

- **Документация API:** `API_DOCUMENTATION.md`
- **Полный отчет:** `REVISION_REPORT_2026-02-13.md`
- **Аудит:** `AUDIT_REPORT.md`
