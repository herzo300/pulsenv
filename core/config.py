# core/config.py
"""
Централизованная конфигурация приложения.
Единый источник правды — все настройки загружаются здесь.
"""

import os
import logging
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# ===== Telegram =====
TG_BOT_TOKEN: str = os.getenv("TG_BOT_TOKEN", "")
WEBHOOK_BASE_URL: str = os.getenv("WEBHOOK_BASE_URL", "")
TG_API_ID: str = os.getenv("TG_API_ID", "")
TG_API_HASH: str = os.getenv("TG_API_HASH", "")
TG_PHONE: str = os.getenv("TG_PHONE", "")
TG_2FA_PASSWORD: str = os.getenv("TG_2FA_PASSWORD", "")
TARGET_CHANNEL: str = os.getenv("TARGET_CHANNEL", "@monitornv")


# ===== Firebase =====
FIREBASE_RTDB_URL: str = os.getenv("FIREBASE_RTDB_URL", "")
FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "")

# ===== Public API / Supabase / Workers =====
_LOCAL_API: str = os.getenv("PUBLIC_API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")
PUBLIC_API_BASE_URL: str = _LOCAL_API

USE_SUPABASE_PRIMARY: bool = os.getenv("USE_SUPABASE_PRIMARY", "false").lower() == "true"

SUPABASE_URL: str = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_FUNCTIONS_URL: str = os.getenv(
    "SUPABASE_FUNCTIONS_URL",
    f"{SUPABASE_URL}/functions/v1/api" if SUPABASE_URL else "",
).rstrip("/")

WORKER_URL: str = SUPABASE_FUNCTIONS_URL or PUBLIC_API_BASE_URL

# ===== Database =====
DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./soobshio.db")

# ===== Admin =====
ADMIN_TELEGRAM_IDS: list[int] = [
    int(uid.strip())
    for uid in os.getenv("ADMIN_TELEGRAM_IDS", "").split(",")
    if uid.strip().isdigit()
]

# ===== VK =====
VK_SERVICE_TOKEN: str = os.getenv("VK_SERVICE_TOKEN", "")

# ===== MCP Fetch Server =====
MCP_FETCH_SERVER_URL: str = os.getenv("MCP_FETCH_SERVER_URL", "http://localhost:3000")
MCP_FETCH_ENABLED: bool = os.getenv("MCP_FETCH_ENABLED", "false").lower() == "true"
MCP_FETCH_TIMEOUT: float = float(os.getenv("MCP_FETCH_TIMEOUT", "30.0"))

# ===== Other =====
JWT_SECRET: str = os.getenv("JWT_SECRET", "")
NV_OPENDATA_API_KEY: str = os.getenv("NV_OPENDATA_API_KEY", "")

# ===== Performance Settings =====
CACHE_TTL: int = 3600 * 24  # 24 hours
CACHE_MAX_SIZE: int = 1000

RATE_LIMIT_COMPLAINT: int = 5   # complaints per minute
RATE_LIMIT_ADMIN: int = 30      # admin commands per minute
RATE_LIMIT_GENERAL: int = 20    # general commands per minute

REALTIME_UPDATE_INTERVAL: int = 3  # seconds for web-app

# ===== Settings object (backward compatibility) =====
# Deprecated: Use module-level variables directly.
class Settings:
    """Legacy settings wrapper. Prefer importing module-level constants directly."""

    def __getattr__(self, name: str):
        # Dynamically resolve any config variable so callers like `settings.FOO`
        # always get the current module-level value without manual duplication.
        import core.config as _cfg
        try:
            return getattr(_cfg, name)
        except AttributeError:
            raise AttributeError(f"Config has no setting '{name}'")


settings = Settings()
