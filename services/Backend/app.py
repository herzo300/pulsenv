# services/Backend/app.py — FastAPI application entry point
"""
Main FastAPI application. Assembles all routers and middleware.
Static file serving for map/infographic pages.
"""

import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

from .routers import ai, complaints, core, opendata, reports
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


app = FastAPI(title="СообщиО API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# App state for Telegram monitor
app.state.telegram_monitor = None

# --- Routers ---
app.include_router(reports.router, prefix="/api")
app.include_router(core.router)
app.include_router(complaints.router)
app.include_router(ai.router)
app.include_router(telegram_router)

app.include_router(opendata.router)

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


@app.get("/uvr5")
def serve_uvr5():
    """Redirect to UVR5 mini-app URL."""
    uvr5_url = (os.getenv("UVR5_MINIAPP_URL") or "").strip()
    if not uvr5_url:
        return JSONResponse(
            {"ok": False, "error": "UVR5_MINIAPP_URL is not configured"},
            status_code=404,
        )
    return RedirectResponse(uvr5_url, status_code=307)


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
