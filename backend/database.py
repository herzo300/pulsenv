# backend/database.py
"""
Database engine and session configuration.
Supports SQLite (local dev) and PostgreSQL (Supabase pooler).
"""

import logging
import os
import re
from urllib.parse import quote_plus, urlparse

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

load_dotenv()

logger = logging.getLogger(__name__)


def _normalize_supabase_url(url: str) -> str:
    """Fix user info for Supabase pooler: user must be postgres.PROJECT_REF."""
    if "pooler.supabase.com" not in url:
        return url
    if "postgresql" not in url and "postgres://" not in url:
        return url

    ref = os.getenv("SUPABASE_PROJECT_REF", "")
    password = os.getenv("SUPABASE_DB_PASSWORD", "")
    if not ref or not password:
        return url

    url_clean = re.sub(r"@\[([^\]]+)\]", r"@\1", url)
    try:
        u = urlparse(url_clean)
    except Exception:
        return url

    if not u.hostname:
        return url

    # Extract password from URL if env var is empty
    if not password and "@" in u.netloc:
        userinfo = u.netloc.rsplit("@", 1)[0]
        if ":" in userinfo:
            _, password = userinfo.split(":", 1)

    user = f"postgres.{ref}"
    port = u.port or 6543
    db = (u.path or "/postgres").lstrip("/") or "postgres"
    return f"postgresql://{user}:{quote_plus(password)}@{u.hostname}:{port}/{db}"


_raw_url = os.getenv("DATABASE_URL", "sqlite:///./soobshio.db")
DATABASE_URL: str = (
    _normalize_supabase_url(_raw_url) if "postgres" in _raw_url else _raw_url
)

_is_sqlite = DATABASE_URL.startswith("sqlite")

# SQLite doesn't support pool_size / max_overflow — use StaticPool implicitly.
_engine_kwargs: dict = {}
if _is_sqlite:
    _engine_kwargs["connect_args"] = {"check_same_thread": False, "timeout": 30}
else:
    _engine_kwargs["pool_size"] = 10
    _engine_kwargs["max_overflow"] = 20
    _engine_kwargs["pool_pre_ping"] = True
    _engine_kwargs["pool_recycle"] = 3600

engine = create_engine(DATABASE_URL, **_engine_kwargs)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """FastAPI dependency — yields a DB session and closes it after use."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


__all__ = ["engine", "SessionLocal", "Base", "get_db", "DATABASE_URL"]
