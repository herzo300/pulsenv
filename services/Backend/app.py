# services/Backend/app.py — FastAPI application entry point
"""
Main FastAPI application. Assembles all routers and middleware.
Static file serving for map/infographic pages.
"""

import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from .admin_metrics import extract_client_ip, metrics_store
from .security import parse_cors_origins
from .routers import admin_metrics, agent, ai, complaints, core, reports
from .routers import map_data
from .routers import uk_ratings, watchdog, visual_search, vlm, profile, daily_digest
from .routers.telegram_router import router as telegram_router

logger = logging.getLogger(__name__)

# Project root (Soobshio_project)
ROOT = Path(__file__).resolve().parent.parent.parent

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup/shutdown lifecycle."""
    # --- Startup ---
    logger.info("СообщиО API starting up...")

    # Ensure DB tables exist
    try:
        from backend.database import Base, engine

        Base.metadata.create_all(bind=engine)
        logger.info("Database tables verified.")
    except Exception as e:
        logger.warning("Could not initialize DB tables: %s", e)

    yield

    # --- Shutdown ---
    logger.info("СообщиО API shutting down...")
    # Close any active Telegram monitor
    monitor = getattr(app.state, "telegram_monitor", None)
    if monitor:
        try:
            await monitor.stop()
        except Exception as e:
            logger.warning("Error stopping Telegram monitor: %s", e)


# ─── Rate Limiter ───
limiter = Limiter(
    key_func=get_remote_address,
    storage_uri=os.getenv("RATELIMIT_STORAGE_URI", "memory://"),
    strategy="moving-window",
)


app = FastAPI(title="СообщиО API", lifespan=lifespan)

# Attach limiter state for router decorators
app.state.limiter = limiter

def _rate_limit_json_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(
        status_code=429,
        content={
            "error": "rate_limit_exceeded",
            "detail": str(exc.detail),
            "retry_after": int(exc.detail.split(":")[0].split()[-1]) if ":" in str(exc.detail) else 60,
        },
        headers={"Retry-After": "60"},
    )

app.add_exception_handler(RateLimitExceeded, _rate_limit_json_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=parse_cors_origins(os.getenv("BACKEND_CORS_ORIGINS")),
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)

# App state for Telegram monitor
app.state.telegram_monitor = None

# --- Routers ---
app.include_router(reports.router, prefix="/api")
app.include_router(admin_metrics.router, prefix="/api")
app.include_router(map_data.router, prefix="/api")
app.include_router(core.router)
app.include_router(complaints.router)
app.include_router(ai.router, prefix="/api")
app.include_router(agent.router)
app.include_router(telegram_router)

app.include_router(uk_ratings.router)
app.include_router(watchdog.router)
app.include_router(visual_search.router)
app.include_router(vlm.router)
app.include_router(profile.router)
app.include_router(daily_digest.router)



@app.middleware("http")
async def capture_runtime_metrics(request: Request, call_next):
    # Ignore static and health check routes to reduce DB load
    skip_prefixes = ("/health", "/static", "/map", "/public", "/favicon.ico", "/digital-twin", "/3d")
    if request.url.path == "/" or any(request.url.path.startswith(p) for p in skip_prefixes):
        return await call_next(request)

    response = await call_next(request)

    request_bytes = int(request.headers.get("content-length") or 0)
    response_bytes = int(response.headers.get("content-length") or 0)
    device_id = (
        request.headers.get("x-client-device-id")
        or request.headers.get("x-device-id")
        or f"anonymous:{extract_client_ip(request)}"
    ).strip()

    try:
        metrics_store.record_request(
            device_id=device_id[:128],
            ip=extract_client_ip(request),
            path=request.url.path,
            request_bytes=request_bytes,
            response_bytes=response_bytes,
        )
    except Exception as exc:  # pragma: no cover - runtime DB dependent
        logger.warning("Runtime metrics write failed for %s: %s", request.url.path, exc)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
    response.headers.setdefault(
        "Permissions-Policy",
        "camera=(), microphone=(), geolocation=(self)",
    )
    return response

# --- Map & Infographic HTML pages (served from public/) ---
_map_html = ROOT / "public" / "map.html"
_info_html = ROOT / "public" / "info.html"

if _map_html.exists():

    @app.get("/map", response_class=FileResponse)
    def serve_map():
        return FileResponse(_map_html)

    @app.get("/map/map.html", response_class=FileResponse)
    def serve_map_html():
        return FileResponse(_map_html)


if _info_html.exists():

    @app.get("/infographic", response_class=FileResponse)
    def serve_infographic():
        return FileResponse(_info_html)

    @app.get("/map/info.html", response_class=FileResponse)
    def serve_info_html():
        return FileResponse(_info_html)



# --- Cameras page ---
_cameras_html = ROOT / 'public' / 'cameras.html'
if _cameras_html.exists():
    @app.get('/cameras', response_class=FileResponse)
    def serve_cameras():
        return FileResponse(_cameras_html)

# --- VIP Search page (separate file, may not exist) ---
_vip_search_html = ROOT / 'public' / 'vip_search.html'
if _vip_search_html.exists():
    @app.get('/vip_search.html', response_class=FileResponse)
    def serve_vip_search_file():
        return FileResponse(_vip_search_html)


_privacy_policy_html = ROOT / 'public' / 'privacy_policy.html'
if _privacy_policy_html.exists():
    @app.get('/privacy_policy.html', response_class=FileResponse)
    def serve_privacy_policy():
        return FileResponse(_privacy_policy_html)


_user_agreement_html = ROOT / 'public' / 'user_agreement.html'
if _user_agreement_html.exists():
    @app.get('/user_agreement.html', response_class=FileResponse)
    def serve_user_agreement():
        return FileResponse(_user_agreement_html)


# --- Maxun Dashboard page ---
_city_dashboard_html = ROOT / 'public' / 'city_dashboard.html'
if _city_dashboard_html.exists():
    @app.get('/city-dashboard', response_class=FileResponse)
    def serve_city_dashboard():
        return FileResponse(_city_dashboard_html)


# --- Static files (relative to project root) ---
static_dir = ROOT / "static"
map_dir = ROOT / "map"
public_dir = ROOT / "public"

if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
if map_dir.exists():
    app.mount("/map", StaticFiles(directory=str(map_dir)), name="map")
elif public_dir.exists():
    app.mount("/map", StaticFiles(directory=str(public_dir)), name="map")
