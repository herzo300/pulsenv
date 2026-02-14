# backend/init_db.py
from .database import engine, Base
from .models import Report


def init_db():
    """Создание таблиц в БД."""
    Base.metadata.create_all(bind=engine)


if __name__ == "__main__":
    init_db()

# Пример запуска один раз из корня проекта:
#   venv\Scripts\activate
#   python -m backend.init_db
