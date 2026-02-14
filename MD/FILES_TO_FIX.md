# Исправленные файлы для приложения СообщиО

Этот файл содержит исправленные версии всех файлов, которые нужно применить.

## 1. Файл: requirements.txt (исправленная версия)

Сохраните как `requirements.txt` и замените текущий файл:

```
fastapi>=0.100.0
uvicorn[standard]>=0.23.0
sqlalchemy>=2.0.0
python-dotenv>=1.0.0
pydantic>=2.0.0
httpx>=0.25.0
python-multipart>=0.0.6

# Database
# psycopg2-binary>=2.9.0  # PostgreSQL driver (заменено на SQLite)

# Telegram
telethon>=1.40.0
aiogram>=3.0.0

# AI
anthropic>=0.20.0
openai>=1.0.0  # fallback AI

# Data Science
numpy>=1.24.0
hdbscan>=0.8.0

# Testing
pytest>=7.4.0
pytest-asyncio>=0.21.0

# Geo
geopy>=2.4.0

# Caching (опционально)
redis>=4.5.0
```

---

## 2. Файл: routers/reports.py (исправленная версия)

Сохраните как `routers/reports.py` и замените текущий файл:

```python
from typing import Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from backend.database import get_db
from backend.models import Report

router = APIRouter(prefix="/reports", tags=["reports"])


class ReportCreate(BaseModel):
    title: str
    description: Optional[str] = None
    lat: float
    lng: float
    category: str = "other"


@router.post("/")
def create_report(report: ReportCreate, db: Session = Depends(get_db)):
    db_report = Report(**report.model_dump())
    db.add(db_report)
    db.commit()
    db.refresh(db_report)
    return db_report
```

---

## 3. Файл: .gitignore (исправленная версия)

Сохраните как `.gitignore` в корне проекта:

```
# Environment variables
.env

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python

# Virtual environments
.venv/
venv/
ENV/

# IDE
.vscode/
.idea/

# Database
*.db
*.sqlite
*.sqlite3

# Flutter
*.apk
*.ipa
*.dSYM/
flutter_*.lock

# Sessions
*.session
*.session-journal

# OS
.DS_Store
Thumbs.db
```

---

## 4. Удалить дубликат Flutter-кода

Выполните команду в терминале:

```bash
rm -rf lib/lib/
```

---

## 5. Удалить package.json

Выполните команду в терминале:

```bash
rm package.json
```

---

## 🚀 После применения всех исправлений

### 1. Настроить .env
```bash
cp .env.example .env
```

Откройте .env и добавьте реальные API ключи:
- TG_API_ID
- TG_API_HASH
- ANTHROPIC_API_KEY
- OPENAI_API_KEY
- DATABASE_URL (уже есть, можно не менять)
- TARGET_CHANNEL

### 2. Установить зависимости
```bash
python -m venv .venv
.venv\Scripts\activate  # Windows
# или
source .venv/bin/activate  # Linux/Mac
pip install -r requirements.txt
```

### 3. Инициализировать БД
```bash
python -m backend.init_db
```

### 4. Запустить приложение
```bash
python main.py
```

### 5. Запустить Telegram парсер (новый терминал)
```bash
python services/telegram_parser.py
```

---

## 📋 Проверка исправлений

Выполните проверку после применения всех исправлений:

```bash
# Проверить telegram_parser.py
cd Soobshio_project
grep -n "parse_complaint" services/telegram_parser.py && echo "❌ Ошибка найдена!" || echo "✅ Исправлено"

# Проверить reports.py
grep "model_dump()" routers/reports.py && echo "✅ Исправлено" || echo "❌ Нужно исправить"

# Проверить .env.example
ls -la .env.example && echo "✅ Создан" || echo "❌ Не создан"

# Проверить список файлов
ls -la | grep -E "(package.json|lib/lib)" && echo "❌ Ошибки найдены" || echo "✅ Все чисто"
```

---

## ✅ Что было исправлено

1. ✅ Создан .env.example - шаблон конфигурации
2. ✅ Удалены строки 206-212 в telegram_parser.py - неработающий код
3. ⚠️ requirements.txt - убрать psycopg2-binary (вручную)
4. ⚠️ routers/reports.py - .dict() → .model_dump() (вручную)
5. ⚠️ lib/lib/ - дубликат Flutter-кода (вручную)
6. ⚠️ package.json - не используется (вручную)
7. ✅ .gitignore - добавлен (создан)

---

## 📚 Дополнительная документация

- **BUGFIXES.md** - подробные исправления и оптимизации
- **FIXES_SUMMARY.md** - инструкции по ручному исправлению
- **FUNCTIONS_AND_OPTIMIZATIONS.md** - все функции и оптимизации
- **REVISION_REPORT.md** - итоговый отчет
- **QUICK_FIXES.sh** - все команды в одном файле
- **fix_all.py** - автоматический скрипт (если будет работать)

Все исправления документированы и готовы к применению!
