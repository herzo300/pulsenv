# core/config.py
"""
Централизованная конфигурация приложения
Все настройки в одном месте для упрощения управления
"""

import os
from dotenv import load_dotenv

load_dotenv()

# ===== Telegram =====
TG_BOT_TOKEN = os.getenv("TG_BOT_TOKEN", "")
WEBHOOK_BASE_URL = os.getenv("WEBHOOK_BASE_URL", "")  # HTTPS URL для webhook (напр. https://example.com)
TG_API_ID = os.getenv("TG_API_ID", "")
TG_API_HASH = os.getenv("TG_API_HASH", "")
TG_PHONE = os.getenv("TG_PHONE", "")
TG_2FA_PASSWORD = os.getenv("TG_2FA_PASSWORD", "")
TARGET_CHANNEL = os.getenv("TARGET_CHANNEL", "@monitornv")

# ===== OpenRouter AI =====
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
OPENROUTER_TEXT_MODEL = os.getenv("OPENROUTER_TEXT_MODEL", "qwen/qwen3-coder")
OPENROUTER_VISION_MODEL = os.getenv("OPENROUTER_VISION_MODEL", "qwen/qwen-vl-plus")

# ===== Firebase =====
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "")
FIREBASE_API_KEY = os.getenv("FIREBASE_API_KEY", "")
FIREBASE_RTDB_URL = os.getenv("FIREBASE_RTDB_URL", "")
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")

# ===== Cloudflare Worker =====
CF_WORKER = os.getenv("ANTHROPIC_BASE_URL", "https://anthropic-proxy.uiredepositionherzo.workers.dev")

# ===== Database =====
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./soobshio.db")

# ===== Admin =====
ADMIN_TELEGRAM_IDS = [
    int(uid.strip()) for uid in os.getenv("ADMIN_TELEGRAM_IDS", "").split(",")
    if uid.strip().isdigit()
]

# ===== VK =====
VK_SERVICE_TOKEN = os.getenv("VK_SERVICE_TOKEN", "")

# ===== MCP Fetch Server =====
MCP_FETCH_SERVER_URL = os.getenv("MCP_FETCH_SERVER_URL", "http://localhost:3000")
MCP_FETCH_ENABLED = os.getenv("MCP_FETCH_ENABLED", "false").lower() == "true"
MCP_FETCH_TIMEOUT = float(os.getenv("MCP_FETCH_TIMEOUT", "30.0"))

# ===== Other =====
JWT_SECRET = os.getenv("JWT_SECRET", "")
NV_OPENDATA_API_KEY = os.getenv("NV_OPENDATA_API_KEY", "")

# ===== Performance Settings =====
# Кэширование
CACHE_TTL = 3600 * 24  # 24 часа
CACHE_MAX_SIZE = 1000

# Rate Limiting
RATE_LIMIT_COMPLAINT = 5  # жалоб в минуту
RATE_LIMIT_ADMIN = 30  # команд в минуту
RATE_LIMIT_GENERAL = 20  # команд в минуту

# Firebase
FIREBASE_MAX_RETRIES = 3
FIREBASE_RETRY_DELAY = 2  # секунды

# Real-time updates
REALTIME_UPDATE_INTERVAL = 3  # секунды для веб-приложения

# ===== Settings object для обратной совместимости =====
class Settings:
    """Объект настроек для обратной совместимости"""
    def __init__(self):
        self.TG_BOT_TOKEN = TG_BOT_TOKEN
        self.CF_WORKER = CF_WORKER
        self.ADMIN_TELEGRAM_IDS = ADMIN_TELEGRAM_IDS
        self.OPENROUTER_API_KEY = OPENROUTER_API_KEY
        self.OPENROUTER_TEXT_MODEL = OPENROUTER_TEXT_MODEL
        self.OPENROUTER_VISION_MODEL = OPENROUTER_VISION_MODEL
        self.FIREBASE_RTDB_URL = FIREBASE_RTDB_URL
        self.DATABASE_URL = DATABASE_URL

settings = Settings()
