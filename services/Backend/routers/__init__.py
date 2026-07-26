# services/Backend/routers/__init__.py
"""Re-export all API routers for convenient imports."""

from services.Backend.routers._legacy_core_router import router as core  # LEGACY — not mounted
from services.Backend.routers.admin_metrics import router as admin_metrics
from services.Backend.routers.agent import router as agent
from services.Backend.routers.ai import router as ai
from services.Backend.routers.ai_utilities import router as ai_utilities
from services.Backend.routers.cameras import router as cameras
from services.Backend.routers.complaints import router as complaints
from services.Backend.routers.daily_digest import router as daily_digest
from services.Backend.routers.error_handler import api_error, api_success
from services.Backend.routers.fuel import router as fuel
from services.Backend.routers.gamification import router as gamification
from services.Backend.routers.geocoding import router as geocoding
from services.Backend.routers.health_config import router as health_config
from services.Backend.routers.map_data import router as map_data
from services.Backend.routers.mobile_complaints import router as mobile_complaints
from services.Backend.routers.payments import router as payments
from services.Backend.routers.profile import router as profile
from services.Backend.routers.pulse_stats import router as pulse_stats
from services.Backend.routers.reports import router as reports
from services.Backend.routers.storage import router as storage
from services.Backend.routers.uk_ratings import router as uk_ratings
from services.Backend.routers.vlm import router as vlm
from services.Backend.routers import weather_alerts

__all__ = [
    "admin_metrics",
    "agent",
    "ai",
    "ai_utilities",
    "api_error",
    "api_success",
    "cameras",
    "complaints",
    "core",  # LEGACY — migrate to split routers
    "daily_digest",
    "fuel",
    "gamification",
    "geocoding",
    "health_config",
    "map_data",
    "mobile_complaints",
    "payments",
    "profile",
    "pulse_stats",
    "reports",
    "storage",
    "uk_ratings",
    "vlm",
    "weather_alerts",
]
