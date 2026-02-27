# services/Backend/app.py — FastAPI приложение (вариант 2: бэкенд в services/)
import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, RedirectResponse, JSONResponse

from .routers import reports, core, complaints, ai, fcm, opendata
from .routers.telegram_router import router as telegram_router

# Корень проекта (Soobshio_project) для static/map
ROOT = Path(__file__).resolve().parent.parent.parent

app = FastAPI(title="СообщиО API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Состояние для Telegram-монитора и FCM
app.state.telegram_monitor = None
app.state.fcm_tokens = {}

# Роутеры
app.include_router(reports.router, prefix="/api")
app.include_router(core.router)
app.include_router(complaints.router)
app.include_router(ai.router)
app.include_router(telegram_router)
app.include_router(fcm.router)
app.include_router(opendata.router)

# Карта и инфографика — явная раздача из public
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
    """Проксирующая точка для UVR5 mini app без Cloudflare Worker."""
    uvr5_url = (os.getenv("UVR5_MINIAPP_URL") or "").strip()
    if not uvr5_url:
        return JSONResponse({"ok": False, "error": "UVR5_MINIAPP_URL is not configured"}, status_code=404)
    return RedirectResponse(uvr5_url, status_code=307)

# Telegram Webhook endpoint
from fastapi import Request

@app.post("/webhook/telegram")
async def telegram_webhook(request: Request):
    """Обработка webhook от Telegram."""
    try:
        from services.telegram_bot import process_webhook_update
        body = await request.json()
        await process_webhook_update(body)
        return JSONResponse({"ok": True})
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"Telegram webhook error: {e}")
        return JSONResponse({"ok": False, "error": str(e)}, status_code=500)


# Static files (относительно корня проекта)
static_dir = ROOT / "static"
map_dir = ROOT / "map"
public_dir = ROOT / "public"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
if map_dir.exists():
    app.mount("/map", StaticFiles(directory=str(map_dir)), name="map")
elif public_dir.exists():
    app.mount("/map", StaticFiles(directory=str(public_dir)), name="map")
