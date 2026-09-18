# backend/database.py
"""
Database engine and session configuration.
Supports SQLite (local dev) and PostgreSQL runtime deployments.
"""

import logging
import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.dialects.postgresql.base import PGDialect
from sqlalchemy.orm import declarative_base, sessionmaker

logger = logging.getLogger(__name__)
# data_layer is at services/data_layer, project root is 2 levels up
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent


def _load_environment() -> None:
    explicit_path = (os.getenv("SOOBSHIO_ENV_FILE") or "").strip()
    candidate_paths = [
        Path(explicit_path) if explicit_path else None,
        Path.home() / ".soobshio" / "runtime.env",
        PROJECT_ROOT / ".env.runtime",
        PROJECT_ROOT / ".env",
        Path.cwd() / ".env.runtime",
        Path.cwd() / ".env",
    ]

    for candidate in candidate_paths:
        if not candidate or not candidate.exists():
            continue
        load_dotenv(dotenv_path=candidate, override=False)
        logger.info("Loaded environment from %s", candidate)
        return


_load_environment()


def _patch_postgres_dialect() -> None:
    original = getattr(PGDialect, "_set_backslash_escapes", None)
    original_version = getattr(PGDialect, "_get_server_version_info", None)
    original_schema = getattr(PGDialect, "_get_default_schema_name", None)
    if (
        not callable(original)
        or not callable(original_version)
        or not callable(original_schema)
        or getattr(PGDialect, "_soobshio_patched", False)
    ):
        return

    def _safe_set_backslash_escapes(self, connection) -> None:
        value = None
        dbapi_conn = getattr(connection.connection, "dbapi_connection", None)
        getter = getattr(dbapi_conn, "get_parameter_status", None)
        if callable(getter):
            try:
                value = getter("standard_conforming_strings")
            except Exception:
                value = None

        if value is None:
            try:
                value = connection.exec_driver_sql(
                    "show standard_conforming_strings"
                ).scalar()
            except Exception:
                value = "on"

        self._backslash_escapes = str(value).strip().lower() == "off"

    def _safe_get_server_version_info(self, connection):
        value = None
        dbapi_conn = getattr(connection.connection, "dbapi_connection", None)
        getter = getattr(dbapi_conn, "get_parameter_status", None)
        if callable(getter):
            try:
                value = getter("server_version")
            except Exception:
                value = None

        if value:
            parts = []
            for item in str(value).split("."):
                if item.isdigit():
                    parts.append(int(item))
                else:
                    break
            if parts:
                return tuple(parts)

        return original_version(self, connection)

    def _safe_get_default_schema_name(self, connection):
        try:
            return original_schema(self, connection)
        except Exception:
            return "public"

    PGDialect._set_backslash_escapes = _safe_set_backslash_escapes
    PGDialect._get_server_version_info = _safe_get_server_version_info
    PGDialect._get_default_schema_name = _safe_get_default_schema_name
    PGDialect._soobshio_patched = True


_patch_postgres_dialect()


_raw_url = os.getenv("DATABASE_URL", "sqlite:///./soobshio.db")
DATABASE_URL: str = _raw_url

_is_sqlite = DATABASE_URL.startswith("sqlite")

# SQLite doesn't support pool_size / max_overflow — use StaticPool implicitly.
_engine_kwargs: dict = {}
if _is_sqlite:
    _engine_kwargs["connect_args"] = {"check_same_thread": False, "timeout": 30}
else:
    _engine_kwargs["pool_size"] = 20
    _engine_kwargs["max_overflow"] = 30
    _engine_kwargs["pool_pre_ping"] = True
    _engine_kwargs["pool_recycle"] = 3600
    _engine_kwargs["connect_args"] = {
        "connect_timeout": 10,
        "application_name": "soobshio_backend",
    }

engine = create_engine(DATABASE_URL, **_engine_kwargs)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """FastAPI dependency — yields a DB session and closes it after use."""
    db = SessionLocal()
    try:
        yield db
    finally:
        try:
            db.close()
        except Exception as exc:  # pragma: no cover - runtime DB dependent
            logger.warning("DB session close failed: %s", exc)


__all__ = ["engine", "SessionLocal", "Base", "get_db", "DATABASE_URL"]
