# services/Backend/app.py — FastAPI application entry point
"""
Main FastAPI application. Assembles all routers and middleware.
Static file serving for map/infographic pages.
"""

import asyncio
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from services.Backend.admin_metrics import extract_client_ip, metrics_store
from services.Backend.routers import (
    admin_metrics,
    agent,
    ai,
    ai_utilities,
    cameras,
    complaints,
    daily_digest,
    gamification,
    geocoding,
    health_config,
    map_data,
    mobile_complaints,
    payments,
    profile,
    pulse_stats,
    reports,
    storage,
    uk_ratings,
    vlm,
    weather_alerts,
)
from services.Backend.routers.fuel import router as fuel_router
from services.Backend.routers.fuel_stations import router as fuel_stations_router
from services.Backend.routers.jkh_audit import router as jkh_audit_router
from services.Backend.routers.sos import router as sos_router
from services.Backend.routers.dispatcher import router as dispatcher_router
from services.Backend.routers.daily_fun import router as daily_fun_router
from services.Backend.routers.transport import router as transport_router
from services.Backend.routers import viseron as viseron_router
from services.Backend.routers.yandex_kassa import router as yandex_router
from services.Backend.routers.cameras import CameraAnalyzeRequest, analyze_camera_free
from services.Backend.routers.telegram_router import router as telegram_router
from services.Backend.routers.webrtc_proxy import router as webrtc_proxy_router
from services.Backend.routers.passkeys import router as passkeys_router
from services.Backend.routers.pmtiles_server import router as pmtiles_server_router
from services.Backend.routers.predictive_maintenance import router as predictive_maintenance_router
from services.Backend.routers.watchdog import router as watchdog_router
from services.Backend.security import parse_cors_origins

logger = logging.getLogger(__name__)

# Project root (Soobshio_project)
ROOT = Path(__file__).resolve().parent.parent.parent


# Bounded queue for metrics (size: 1000 items)
_metrics_queue = asyncio.Queue(maxsize=1000)


async def _metrics_worker():
    while True:
        try:
            item = await _metrics_queue.get()
            await asyncio.to_thread(
                metrics_store.record_request,
                device_id=item["device_id"],
                ip=item["ip"],
                path=item["path"],
                request_bytes=item["request_bytes"],
                response_bytes=item["response_bytes"],
            )
            _metrics_queue.task_done()
        except asyncio.CancelledError:
            break
        except Exception as exc:
            logger.warning("Error in metrics background worker: %s", exc)
            await asyncio.sleep(1)


def check_and_add_columns():
    """Verify and add missing columns to database tables (like push_sent in reports)."""
    from sqlalchemy import text
    from services.data_layer.database import SessionLocal, DATABASE_URL
    db = SessionLocal()
    try:
        is_sqlite = DATABASE_URL.startswith("sqlite")
        if is_sqlite:
            res = db.execute(text("PRAGMA table_info(reports)")).fetchall()
            cols = [r[1] for r in res]
        else:
            res = db.execute(text(
                "SELECT column_name FROM information_schema.columns WHERE table_name='reports'"
            )).fetchall()
            cols = [r[0] for r in res]
            
        if "push_sent" not in cols:
            logger.info("Adding push_sent column to reports table")
            db.execute(text("ALTER TABLE reports ADD COLUMN push_sent BOOLEAN DEFAULT FALSE"))
            db.commit()
    except Exception as e:
        logger.warning("Failed to auto-verify database columns: %s", e)
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup/shutdown lifecycle."""
    # --- Startup ---
    logger.info("СообщиО API starting up...")

    # Start metrics background worker
    worker_task = asyncio.create_task(_metrics_worker())
    app.state.metrics_worker = worker_task

    # Clean up stale camera cache files on startup
    try:
        from services.business.camera_frame_cache import clean_old_cache
        clean_old_cache(max_age_seconds=600)
    except Exception as exc:
        logger.warning("Failed to clean up camera frame cache on startup: %s", exc)

    # Ensure DB tables exist (dev fallback; production should use alembic upgrade head)
    if os.getenv("PRODUCTION", "").lower() in ("1", "true", "yes"):
        if os.getenv("DB_AUTO_CREATE", "true").lower() in ("1", "true", "yes"):
            logger.error(
                "FATAL: DB_AUTO_CREATE must be false in production. "
                "Run `alembic upgrade head` instead."
            )
            raise RuntimeError("DB_AUTO_CREATE must be false in production")

    if os.getenv("DB_AUTO_CREATE", "true").lower() in ("1", "true", "yes"):
        try:
            from services.data_layer.database import Base, engine

            Base.metadata.create_all(bind=engine)

            # Gamification tables are now handled by SQLAlchemy MetaData via models.py
            logger.info("Gamification tables verified.")
        except Exception as e:
            logger.warning("Could not initialize DB tables: %s", e)
    else:
        logger.info("DB_AUTO_CREATE disabled — expecting alembic migrations")

    try:
        check_and_add_columns()
    except Exception as e:
        logger.warning("Failed to run check_and_add_columns: %s", e)

    # Optional report retention cleanup (disabled by default)
    if os.getenv("REPORT_RETENTION_CLEANUP_ENABLED", "false").lower() in (
        "1",
        "true",
        "yes",
    ):
        try:
            from services.data_layer.database import SessionLocal
            from services.data_layer.models import Report
            from datetime import datetime, timedelta

            retention_days = int(os.getenv("REPORT_RETENTION_DAYS", "30"))
            db_session = SessionLocal()
            try:
                cutoff = datetime.utcnow() - timedelta(days=retention_days)
                deleted = (
                    db_session.query(Report)
                    .filter(Report.created_at < cutoff)
                    .delete()
                )
                db_session.commit()
                logger.info(
                    "Report retention cleanup: deleted %d reports older than %d days.",
                    deleted,
                    retention_days,
                )
            except Exception as err:
                db_session.rollback()
                logger.warning("Report retention cleanup error: %s", err)
            finally:
                db_session.close()
        except Exception as err:
            logger.warning(
                "Could not initialize DB session for retention cleanup: %s", err
            )

    try:
        from services.Backend.routers.weather_alerts import start_alerts_background_loop

        await start_alerts_background_loop(app)
    except Exception as e:
        logger.warning("Alerts background loop not started: %s", e)

    if os.getenv("TG_AUTO_START_MONITOR", "true").lower() in ("1", "true", "yes"):
        try:
            from services.data_layer.database import SessionLocal
            from services.monitoring.config import CHANNELS_TO_MONITOR
            from services.telegram_monitor import start_telegram_monitoring

            api_id = int(os.getenv("TG_API_ID", "0") or "0")
            api_hash = os.getenv("TG_API_HASH", "").strip()
            phone = os.getenv("TG_PHONE", "").strip()
            if api_id and api_hash and phone:
                db = SessionLocal()
                monitor = await start_telegram_monitoring(
                    api_id=api_id,
                    api_hash=api_hash,
                    phone=phone,
                    channels=CHANNELS_TO_MONITOR,
                    bot_token=os.getenv("TG_BOT_TOKEN", "").strip() or None,
                    db=db,
                )
                app.state.telegram_monitor = monitor
                logger.info(
                    "Telegram monitor auto-started (%d channels)",
                    len(CHANNELS_TO_MONITOR),
                )
            else:
                logger.warning(
                    "Telegram monitor auto-start skipped: TG_API_ID/HASH/PHONE missing"
                )
        except Exception as e:
            logger.warning("Telegram monitor auto-start failed: %s", e)

    yield

    # --- Shutdown ---
    logger.info("СообщиО API shutting down...")
    metrics_worker = getattr(app.state, "metrics_worker", None)
    if metrics_worker:
        metrics_worker.cancel()
        try:
            await metrics_worker
        except asyncio.CancelledError:
            pass

    alerts_task = getattr(app.state, "alerts_task", None)
    if alerts_task:
        alerts_task.cancel()
        try:
            await alerts_task
        except asyncio.CancelledError:
            pass

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
            "retry_after": int(exc.detail.split(":")[0].split()[-1])
            if ":" in str(exc.detail)
            else 60,
        },
        headers={"Retry-After": "60"},
    )


app.add_exception_handler(RateLimitExceeded, _rate_limit_json_handler)


@app.exception_handler(Exception)
async def _unhandled_exception_handler(request: Request, exc: Exception):
    logger.exception("Unhandled error on %s: %s", request.url.path, exc)
    detail = "Internal server error"
    if os.getenv("PRODUCTION", "").lower() not in ("1", "true", "yes"):
        detail = f"{type(exc).__name__}: {exc}"
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": {"code": "internal_error", "detail": detail},
        },
    )


from fastapi.middleware.gzip import GZipMiddleware

app.add_middleware(GZipMiddleware, minimum_size=500)

app.add_middleware(
    CORSMiddleware,
    allow_origins=parse_cors_origins(os.getenv("BACKEND_CORS_ORIGINS")),
    allow_methods=["GET", "POST", "PUT", "PATCH", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-Requested-With"],
    allow_credentials=True,
)


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    """Add security headers and request-ID tracing to all responses."""
    import uuid as _uuid
    request_id = str(_uuid.uuid4())[:8]
    response = await call_next(request)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("X-XSS-Protection", "1; mode=block")
    response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
    response.headers["X-Request-ID"] = request_id
    # HSTS in production
    if os.getenv("PRODUCTION") == "true":
        response.headers.setdefault(
            "Strict-Transport-Security", "max-age=31536000; includeSubDomains"
        )
    response.headers.setdefault(
        "Permissions-Policy",
        "camera=(), microphone=(), geolocation=(self)",
    )
    # CSP for HTML pages — restrict script sources
    if request.url.path.endswith(".html") or request.url.path in ("/", "/health"):
        response.headers.setdefault(
            "Content-Security-Policy",
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdn.jsdelivr.org https://fonts.googleapis.com https://unpkg.com; "
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://unpkg.com https://cdn.jsdelivr.net; "
            "font-src 'self' https://fonts.gstatic.com; "
            "img-src 'self' data: https: blob:; "
            "media-src 'self' https: blob:; "
            "connect-src 'self' https: wss: ws:; "
            "frame-ancestors 'none';",
        )
    return response

# App state for Telegram monitor
app.state.telegram_monitor = None

# --- Routers ---
# NOTE: core.py is LEGACY — disabled in favor of split routers.
# Re-enable only if specific endpoints are still needed.
# app.include_router(core.router)  # LEGACY: DO NOT USE

# New split routers (replaces core.py god-router)
app.include_router(health_config)           # /, /health, /config, /categories, /api/infographic
app.include_router(pulse_stats)             # /api/pulse/stats
app.include_router(storage)                 # /api/storage/*, /api/pages/*
app.include_router(geocoding)               # /api/geo/reverse
app.include_router(mobile_complaints)       # POST /complaints
app.include_router(payments)                # /api/stars/*, /api/collective-email
app.include_router(ai_utilities)            # /api/rag/ask, /api/sentiment, /api/ocr

# Domain routers (unchanged)
app.include_router(cameras)
app.include_router(reports, prefix="/api")
app.include_router(admin_metrics, prefix="/api")
app.include_router(map_data, prefix="/api")
app.include_router(complaints)
app.include_router(ai, prefix="/api")
app.include_router(agent)
app.include_router(telegram_router)
app.include_router(uk_ratings)
app.include_router(vlm, prefix="/api")
app.include_router(profile)
app.include_router(daily_digest)
app.include_router(weather_alerts.router)
app.include_router(gamification)
app.include_router(viseron_router.router)
app.include_router(transport_router, prefix="/api/transport")
app.include_router(fuel_router)  # /api/fuel/prices, /api/fuel/best
app.include_router(fuel_stations_router)  # /api/fuel/stations, /api/fuel/scan-status
app.include_router(jkh_audit_router)  # /api/jkh/audit, /api/jkh/tariffs
app.include_router(sos_router)  # /api/sos/share, /api/sos/invite, /api/sos/live-locations
app.include_router(dispatcher_router)  # /api/dispatcher/optimize-route, /api/dispatcher/find-bus
app.include_router(daily_fun_router, prefix="/api")  # /api/daily-fun
app.include_router(yandex_router, prefix="/api/yookassa")  # /api/yookassa/create
app.include_router(webrtc_proxy_router)  # /api/v1/webrtc/whep
app.include_router(passkeys_router)  # /api/v1/auth/passkey/*
app.include_router(pmtiles_server_router)  # /api/v1/pmtiles/*
app.include_router(pmtiles_server_router, prefix="/api/pmtiles")  # /api/pmtiles/*
app.include_router(predictive_maintenance_router)  # /api/v1/predictive/risk-map
app.include_router(watchdog_router)  # /api/watchdog/*


@app.middleware("http")
async def capture_runtime_metrics(request: Request, call_next):
    # Ignore static and health check routes to reduce DB load
    skip_prefixes = (
        "/health",
        "/static",
        "/map",
        "/public",
        "/favicon.ico",
        "/digital-twin",
        "/3d",
    )
    if request.url.path == "/" or any(
        request.url.path.startswith(p) for p in skip_prefixes
    ):
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
        _metrics_queue.put_nowait({
            "device_id": device_id[:128],
            "ip": extract_client_ip(request),
            "path": request.url.path,
            "request_bytes": request_bytes,
            "response_bytes": response_bytes,
        })
    except asyncio.QueueFull:
        logger.warning("Metrics queue full, dropping metric for path %s", request.url.path)
    except Exception as exc:  # pragma: no cover
        logger.warning("Runtime metrics queuing failed for %s: %s", request.url.path, exc)
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
_cameras_html = ROOT / "public" / "cameras.html"
if _cameras_html.exists():

    @app.get("/cameras", response_class=FileResponse)
    def serve_cameras():
        return FileResponse(_cameras_html)


# --- VIP Search page (separate file, may not exist) ---
_vip_search_html = ROOT / "public" / "vip_search.html"
if _vip_search_html.exists():

    @app.get("/vip_search.html", response_class=FileResponse)
    def serve_vip_search_file(request: Request):
        from services.Backend.security import is_feature_enabled, require_admin_api_token

        if is_feature_enabled("ENABLE_OSINT") or is_feature_enabled(
            "ENABLE_PERSON_SEARCH"
        ):
            require_admin_api_token(request)
        return FileResponse(_vip_search_html)


_privacy_policy_html = ROOT / "public" / "privacy_policy.html"
if _privacy_policy_html.exists():

    @app.get("/privacy_policy.html", response_class=FileResponse)
    def serve_privacy_policy():
        return FileResponse(_privacy_policy_html)


_user_agreement_html = ROOT / "public" / "user_agreement.html"
if _user_agreement_html.exists():

    @app.get("/user_agreement.html", response_class=FileResponse)
    def serve_user_agreement():
        return FileResponse(_user_agreement_html)


# --- Maxun Dashboard page ---
_city_dashboard_html = ROOT / "public" / "city_dashboard.html"
if _city_dashboard_html.exists():

    @app.get("/city-dashboard", response_class=FileResponse)
    def serve_city_dashboard():
        return FileResponse(_city_dashboard_html)


# --- Lost & Found Animals and Items Page ---
_lost_found_html = ROOT / "public" / "lost_found.html"
if _lost_found_html.exists():

    @app.get("/lost_found", response_class=FileResponse)
    def serve_lost_found():
        return FileResponse(_lost_found_html)

    @app.get("/lost_found.html", response_class=FileResponse)
    def serve_lost_found_html():
        return FileResponse(_lost_found_html)


# --- 3D Map Dashboard Page ---
_map3d_html = ROOT / "public" / "map3d.html"
if _map3d_html.exists():

    @app.get("/map3d", response_class=FileResponse)
    def serve_map3d():
        return FileResponse(_map3d_html)

    @app.get("/map3d.html", response_class=FileResponse)
    def serve_map3d_html():
        return FileResponse(_map3d_html)


# --- ESIA Mock Page ---
_esia_mock_html = ROOT / "public" / "esia_mock.html"
if _esia_mock_html.exists():

    @app.get("/esia_mock", response_class=FileResponse)
    def serve_esia_mock():
        return FileResponse(_esia_mock_html)

@app.get("/static/nizhnevartovsk.pmtiles", response_class=FileResponse)
def get_nizhnevartovsk_pmtiles():
    """
    Get offline vector map tiles. If file does not exist, extract it from
    Protomaps remote repository using dynamic bbox filtering.
    """
    import subprocess
    import shutil
    from pathlib import Path
    
    target_path = ROOT / "static" / "nizhnevartovsk.pmtiles"
    
    if target_path.exists() and target_path.stat().st_size > 500 * 1024:
        return FileResponse(target_path)
        
    logger.info("pmtiles file missing or too small. Attempting to download/extract...")
    target_path.parent.mkdir(parents=True, exist_ok=True)
    
    pmtiles_bin = shutil.which("pmtiles")
    
    if not pmtiles_bin:
        local_bin = ROOT / "bin" / "pmtiles"
        if os.name == 'nt':
            local_bin = ROOT / "bin" / "pmtiles.exe"
        if local_bin.exists():
            pmtiles_bin = str(local_bin)
            
    if not pmtiles_bin:
        import urllib.request
        bin_dir = ROOT / "bin"
        bin_dir.mkdir(parents=True, exist_ok=True)
        
        try:
            if os.name == 'nt':
                url = "https://github.com/protomaps/go-pmtiles/releases/download/v1.23.0/go-pmtiles_1.23.0_windows_amd64.zip"
                zip_path = bin_dir / "pmtiles.zip"
                logger.info(f"Downloading pmtiles.exe from {url}...")
                urllib.request.urlretrieve(url, zip_path)
                
                import zipfile
                with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                    zip_ref.extractall(bin_dir)
                
                exe_matches = list(bin_dir.glob("**/pmtiles.exe"))
                if exe_matches:
                    shutil.copy2(exe_matches[0], bin_dir / "pmtiles.exe")
                pmtiles_bin = str(bin_dir / "pmtiles.exe")
            else:
                url = "https://github.com/protomaps/go-pmtiles/releases/download/v1.23.0/go-pmtiles_1.23.0_linux_amd64.tar.gz"
                tar_path = bin_dir / "pmtiles.tar.gz"
                logger.info(f"Downloading pmtiles from {url}...")
                urllib.request.urlretrieve(url, tar_path)
                
                import tarfile
                with tarfile.open(tar_path, "r:gz") as tar_ref:
                    tar_ref.extractall(bin_dir)
                
                matches = list(bin_dir.glob("**/pmtiles"))
                if matches:
                    shutil.copy2(matches[0], bin_dir / "pmtiles")
                    os.chmod(bin_dir / "pmtiles", 0o755)
                pmtiles_bin = str(bin_dir / "pmtiles")
        except Exception as dl_err:
            logger.error(f"Failed to download/extract pmtiles CLI: {dl_err}")
            
    if pmtiles_bin:
        cmd = [
            pmtiles_bin,
            "extract",
            "https://build.protomaps.com/latest.pmtiles",
            str(target_path),
            "--bbox=76.45,60.90,76.65,60.98",
            "--force"
        ]
        logger.info(f"Executing: {' '.join(cmd)}")
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            if res.returncode == 0 and target_path.exists() and target_path.stat().st_size > 500 * 1024:
                logger.info("Successfully extracted Nizhnevartovsk pmtiles.")
                return FileResponse(target_path)
            else:
                logger.error(f"pmtiles extract failed (code {res.returncode}): {res.stderr}")
        except Exception as run_err:
            logger.error(f"Failed running pmtiles CLI: {run_err}")
            
    raise HTTPException(status_code=404, detail="Offline map file not generated yet. Try again later.")


# --- Static files (relative to project root) ---
static_dir = ROOT / "static"
map_dir = ROOT / "map"
public_dir = ROOT / "public"

try:
    static_dir.mkdir(parents=True, exist_ok=True)
    public_dir.mkdir(parents=True, exist_ok=True)
    (static_dir / "uploads" / "pdf_claims").mkdir(parents=True, exist_ok=True)
    (public_dir / "uploads" / "pdf_claims").mkdir(parents=True, exist_ok=True)
except Exception as e:
    logger.warning("Directory creation skipped or read-only: %s", e)

app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
app.mount("/public", StaticFiles(directory=str(public_dir)), name="public")

if map_dir.exists():
    app.mount("/map", StaticFiles(directory=str(map_dir)), name="map")
elif public_dir.exists():
    app.mount("/map", StaticFiles(directory=str(public_dir)), name="map")
