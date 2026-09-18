# services/Backend/routers/health_config.py
"""Health check, runtime config, and categories endpoints."""

import logging
import os
from pathlib import Path
from urllib.parse import urlsplit

from fastapi import APIRouter, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

logger = logging.getLogger(__name__)

router = APIRouter(tags=["health-config"])
ROOT = Path(__file__).resolve().parents[3]
INFOGRAPHIC_CANDIDATES = (
    ROOT / "services" / "Frontend" / "assets" / "infographic_data.json",
    ROOT / "public" / "infographic_data.json",
)


def _resolve_infographic_json() -> Path | None:
    for candidate in INFOGRAPHIC_CANDIDATES:
        if candidate.exists():
            return candidate
    return None

# Rate limiter for public endpoints
_public_limiter = Limiter(key_func=get_remote_address)


def _normalize_public_base_url(value: str) -> str:
    normalized = value.strip().rstrip("/")
    if not normalized:
        return ""
    parsed = urlsplit(normalized)
    if not parsed.scheme or not parsed.netloc:
        return ""
    path = parsed.path.rstrip("/")
    if path.endswith("/functions/v1/api"):
        return ""
    if path.endswith("/api"):
        normalized = normalized[: -len("/api")]
    return normalized.rstrip("/")


def _resolve_public_base_url(request: Request | None = None) -> str:
    public_base = _normalize_public_base_url(os.getenv("PUBLIC_API_BASE_URL") or "")
    if public_base:
        return public_base
    if request is not None:
        # Trust X-Forwarded-Proto from the reverse proxy (nginx -> backend over HTTP).
        # Otherwise /config would advertise http://, which Android/iOS block in release
        # builds (no cleartext), causing the "ошибка связи с сервером" in the app.
        scheme = (
            request.headers.get("x-forwarded-proto", "").split(",")[0].strip().lower()
            or request.url.scheme
        )
        base = str(request.base_url)
        if scheme == "https" and base.startswith("http://"):
            base = "https://" + base[len("http://"):]
        return base.rstrip("/")
    return ""


@router.get("/")
def root():
    """Root landing page with quick links."""
    from fastapi.responses import HTMLResponse
    return HTMLResponse(
        """
        <!DOCTYPE html>
        <html lang="ru">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>СообщиО</title>
          <style>
            body { font-family: system-ui, sans-serif; margin: 0; background: #0f172a; color: #e2e8f0; }
            main { max-width: 760px; margin: 0 auto; padding: 64px 24px; }
            h1 { margin: 0 0 16px; font-size: 40px; }
            p { color: #cbd5e1; line-height: 1.6; }
            .links { display: flex; flex-wrap: wrap; gap: 12px; margin-top: 28px; }
            a { color: #38bdf8; text-decoration: none; padding: 12px 16px; border: 1px solid rgba(56,189,248,.35); border-radius: 12px; }
          </style>
        </head>
        <body>
          <main>
            <h1>СообщиО</h1>
            <p>Backend-контур проекта запущен. Публичный веб-интерфейс должен открываться через внешний nginx на корневом URL сервиса.</p>
            <div class="links">
              <a href="/health">Health</a>
              <a href="/config">Config</a>
              <a href="/api/reports">Reports API</a>
            </div>
          </main>
        </body>
        </html>
        """
    )


@router.get("/health")
@router.get("/api/health")
def health_check(request: Request):
    """Check API, DB, Redis, and optional Telegram monitor status."""
    from fastapi.responses import JSONResponse

    db_status = "connected"
    db_ok = True
    try:
        from sqlalchemy import text

        from services.data_layer.database import engine

        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as exc:
        logger.warning("Health DB check failed: %s", exc)
        db_status = "disconnected"
        db_ok = False

    redis_status = "not_configured"
    redis_url = (os.getenv("RATELIMIT_STORAGE_URI") or os.getenv("REDIS_URL") or "").strip()
    if redis_url and not redis_url.startswith("memory://"):
        try:
            import redis

            redis_client = redis.from_url(redis_url, socket_connect_timeout=2)
            redis_client.ping()
            redis_status = "connected"
        except Exception as exc:
            logger.warning("Health Redis check failed: %s", exc)
            redis_status = "disconnected"

    monitor = getattr(request.app.state, "telegram_monitor", None)
    payload = {
        "status": "ok" if db_ok else "degraded",
        "database": db_status,
        "redis": redis_status,
        "telegram_monitor": "running" if monitor else "stopped",
        "version": "1.0.0",
        "checks": {
            "database": db_status,
            "redis": redis_status,
            "telegram_monitor": "running" if monitor else "stopped",
        },
    }
    return JSONResponse(status_code=200 if db_ok else 503, content=payload)


@router.get("/config")
def get_config(request: Request):
    """Public runtime config for the Timeweb-hosted frontend."""
    public_base = _resolve_public_base_url(request)
    return {
        "runtimeMode": "timeweb",
        "backendBaseUrl": public_base,
        "publicApiBaseUrl": public_base,
        "storageBaseUrl": f"{public_base}/static",
    }


@router.get("/categories")
def get_categories():
    """Return all complaint categories."""
    from services.ai.zai_service import CATEGORIES
    return {
        "categories": [
            {
                "id": cat[:4] if len(cat) >= 4 else cat,
                "name": cat,
                "icon": "•",
                "color": "#818CF8",
            }
            for cat in CATEGORIES
        ]
    }


@router.get("/api/infographic")
def get_infographic_data():
    """Serve infographic JSON data."""
    import json

    from fastapi import HTTPException
    info_path = _resolve_infographic_json()
    if not info_path:
        raise HTTPException(status_code=404, detail="Infographic data not found")
    try:
        with info_path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=500, detail="Invalid infographic data") from exc


@router.get("/api/infographic_data")
def get_infographic_data_compat(data_type: str | None = None):
    """Compatibility infographic endpoint for legacy Flutter web/mobile clients."""
    import json

    from services.uk_rating_service import get_all_ratings
    info_path = _resolve_infographic_json()
    if not info_path:
        return []
    with info_path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)

    _, _, requested = (data_type or "").partition(".")
    requested = requested or data_type or ""
    if requested == "summary":
        return [{"data_type": "summary", "data": payload}]
    if requested == "uk_list":
        return [{"data_type": "uk_list", "data": get_all_ratings()}]
    return [
        {"data_type": "summary", "data": payload},
        {"data_type": "uk_list", "data": get_all_ratings()},
    ]


@router.get("/reports")
def get_reports_legacy():
    """Legacy endpoint — redirects users to /api/reports."""
    return {"message": "Use /api/reports instead"}
