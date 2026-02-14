from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv
import os

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./soobshio.db")

engine = create_engine(
    DATABASE_URL,
    connect_args={
        "check_same_thread": False,
        "timeout": 30,
    }
    if DATABASE_URL.startswith("sqlite")
    else {},
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
    pool_recycle=3600,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """
    Dependency for FastAPI - yields a database session.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


__all__ = ['engine', 'SessionLocal', 'Base', 'get_db', 'DATABASE_URL']
