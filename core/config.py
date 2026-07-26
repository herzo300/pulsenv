# core/config.py
"""
Централизованная конфигурация приложения.
Единый источник правды — все настройки загружаются здесь.
"""

import logging
import os
import sys

from dotenv import load_dotenv

_PUBLIC_API_ENV_BEFORE_DOTENV = os.environ.get("PUBLIC_API_BASE_URL")
load_dotenv()

logger = logging.getLogger(__name__)


def _require_env(key: str, default: str = "") -> str:
    """Get env var with validation for production mode."""
    value = os.getenv(key, default)
    if not value and os.getenv("PRODUCTION") == "true":
        print(f"FATAL: {key} is required in production mode", file=sys.stderr)
        sys.exit(1)
    return value


# ===== Telegram =====
TG_BOT_TOKEN: str = os.getenv("TG_BOT_TOKEN", "")
if not TG_BOT_TOKEN:
    logger.warning(
        "TG_BOT_TOKEN is not set. Telegram bot functionality will be disabled."
    )

WEBHOOK_BASE_URL: str = os.getenv("WEBHOOK_BASE_URL", "")
TG_API_ID: str = os.getenv("TG_API_ID", "")
TG_API_HASH: str = os.getenv("TG_API_HASH", "")
TG_PHONE: str = os.getenv("TG_PHONE", "")
TG_2FA_PASSWORD: str = os.getenv("TG_2FA_PASSWORD", "")
TARGET_CHANNEL: str = os.getenv("TARGET_CHANNEL", "@monitornv")


# ===== Firebase =====
FIREBASE_RTDB_URL: str = os.getenv("FIREBASE_RTDB_URL", "")
FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "")

# ===== Public API / Workers =====
_PUBLIC_API_SOURCE = (
    _PUBLIC_API_ENV_BEFORE_DOTENV
    if os.getenv("PYTEST_CURRENT_TEST")
    else os.getenv("PUBLIC_API_BASE_URL", "")
)
_PUBLIC_API_RAW: str = (_PUBLIC_API_SOURCE or "").strip().rstrip("/")
if not _PUBLIC_API_RAW:
    logger.warning(
        "PUBLIC_API_BASE_URL is not set. Defaulting to http://localhost:8000. "
        "Set PUBLIC_API_BASE_URL in your .env file for production."
    )
    _PUBLIC_API_RAW = "http://localhost:8000"

PUBLIC_API_BASE_URL: str = _PUBLIC_API_RAW
WORKER_URL: str = PUBLIC_API_BASE_URL

# ===== Database =====
DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./soobshio.db")
if DATABASE_URL.startswith("sqlite") and os.getenv("PRODUCTION") == "true":
    print(
        "FATAL: SQLite is not allowed in production mode. Use PostgreSQL.",
        file=sys.stderr,
    )
    sys.exit(1)

# ===== Admin =====
_ADMIN_IDS_RAW = os.getenv("ADMIN_TELEGRAM_IDS", "")
ADMIN_TELEGRAM_IDS: list[int] = []
if _ADMIN_IDS_RAW:
    for uid in _ADMIN_IDS_RAW.split(","):
        uid = uid.strip()
        if uid.isdigit():
            ADMIN_TELEGRAM_IDS.append(int(uid))
        elif uid:
            logger.warning(
                "Invalid ADMIN_TELEGRAM_IDS value '%s' — must be numeric, skipping.", uid
            )

# ===== VK =====
VK_SERVICE_TOKEN: str = os.getenv("VK_SERVICE_TOKEN", "")

# ===== MCP Fetch Server =====
MCP_FETCH_SERVER_URL: str = os.getenv("MCP_FETCH_SERVER_URL", PUBLIC_API_BASE_URL)
MCP_FETCH_ENABLED: bool = os.getenv("MCP_FETCH_ENABLED", "false").lower() == "true"
MCP_FETCH_TIMEOUT: float = float(os.getenv("MCP_FETCH_TIMEOUT", "30.0"))

# ===== Other =====
JWT_SECRET: str = _require_env("JWT_SECRET", "")
NV_OPENDATA_API_KEY: str = os.getenv("NV_OPENDATA_API_KEY", "")

# ===== Performance Settings =====
CACHE_TTL: int = 3600 * 24  # 24 hours
CACHE_MAX_SIZE: int = 1000

RATE_LIMIT_COMPLAINT: int = 5  # complaints per minute
RATE_LIMIT_ADMIN: int = 30  # admin commands per minute
RATE_LIMIT_GENERAL: int = 20  # general commands per minute

REALTIME_UPDATE_INTERVAL: int = 3  # seconds for web-app
