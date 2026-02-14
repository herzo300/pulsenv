#!/usr/bin/env python3
"""
Скрипт для исправления всех проблем в приложении СообщиО
"""

import os
import shutil

def fix_requirements_txt():
    """Исправить requirements.txt - убрать psycopg2-binary"""
    content = """fastapi>=0.100.0
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
"""

    with open('requirements.txt', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ requirements.txt исправлен")

def fix_reports_py():
    """Исправить routers/reports.py - .dict() → .model_dump()"""
    content = """from typing import Optional
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
"""

    with open('routers/reports.py', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ routers/reports.py исправлен")

def remove_lib_lib():
    """Удалить дубликат Flutter-кода"""
    lib_lib_path = 'lib/lib'
    if os.path.exists(lib_lib_path):
        shutil.rmtree(lib_lib_path)
        print(f"✅ Удалена папка {lib_lib_path}")
    else:
        print(f"⚠️ Папка {lib_lib_path} не найдена")

def remove_package_json():
    """Удалить package.json"""
    package_json_path = 'package.json'
    if os.path.exists(package_json_path):
        os.remove(package_json_path)
        print(f"✅ Удален файл {package_json_path}")
    else:
        print(f"⚠️ Файл {package_json_path} не найден")

def fix_gitignore():
    """Обновить .gitignore"""
    content = """# Environment variables
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
"""

    with open('.gitignore', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ .gitignore обновлен")

def main():
    print("=== Начало исправлений приложения СообщиО ===\n")

    try:
        fix_requirements_txt()
        fix_reports_py()
        remove_lib_lib()
        remove_package_json()
        fix_gitignore()

        print("\n=== Все исправления применены ===")
        print("\n✨ Теперь вы можете:")
        print("1. cd Soobshio_project")
        print("2. cp .env.example .env  # Добавить реальные API ключи")
        print("3. python -m venv .venv")
        print("4. pip install -r requirements.txt")
        print("5. python main.py")

    except Exception as e:
        print(f"\n❌ Ошибка при исправлении: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()
