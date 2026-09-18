# services/Backend/routers/core.py — Root, health, categories, webhook, mobile complaint, email
"""
Core API routes: health checks, config, categories, complaints from mobile,
Telegram webhook receiver, and email sending.
"""

import logging
import os
import json
from pathlib import Path
from urllib.parse import urlsplit

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.responses import FileResponse, HTMLResponse
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session

from services.data_layer.database import get_db
from services.data_layer.models import Report

# Per-router limiter for complaint submission
_complaint_limiter = Limiter(key_func=get_remote_address)
from services.geo_service import reverse_geocode
from services.local_media_storage import ROOT as STORAGE_ROOT
from services.uk_rating_service import get_all_ratings
from services.zai_service import CATEGORIES

logger = logging.getLogger(__name__)

router = APIRouter(tags=["core"])
ROOT = Path(__file__).resolve().parents[3]
INFOGRAPHIC_JSON = ROOT / "services" / "Frontend" / "assets" / "infographic_data.json"
STORAGE_BASE = STORAGE_ROOT / "static" / "uploads"
VIP_SEARCH_HTML = ROOT / "public" / "vip_search.html"
PRIVACY_POLICY_HTML = ROOT / "public" / "privacy_policy.html"
USER_AGREEMENT_HTML = ROOT / "public" / "user_agreement.html"


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
        return str(request.base_url).rstrip("/")
    return ""


@router.get("/")
def root():
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


@router.get("/api/infographic")
def get_infographic_data():
    if not INFOGRAPHIC_JSON.exists():
        raise HTTPException(status_code=404, detail="Infographic data not found")
    try:
        with INFOGRAPHIC_JSON.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=500, detail="Invalid infographic data") from exc


@router.get("/api/infographic_data")
def get_infographic_data_compat(data_type: str | None = None):
    """Compatibility infographic endpoint for legacy Flutter web/mobile clients."""
    if not INFOGRAPHIC_JSON.exists():
        return []
    with INFOGRAPHIC_JSON.open("r", encoding="utf-8") as handle:
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


@router.get("/health")
def health_check(request: Request):
    """Check API, DB, and optional Telegram monitor status."""
    db_status = "unknown"
    try:
        from sqlalchemy import text
        from backend.database import engine

        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        db_status = "connected"
    except Exception:
        db_status = "disconnected"

    monitor = getattr(request.app.state, "telegram_monitor", None)
    return {
        "status": "ok",
        "database": db_status,
        "telegram_monitor": "running" if monitor else "stopped",
        "version": "1.0.0",
    }


@router.get("/categories")
def get_categories():
    """Return all complaint categories."""
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


@router.get("/api/pages/vip-search")
def get_vip_search_page():
    if not VIP_SEARCH_HTML.exists():
        raise HTTPException(status_code=404, detail="VIP page not found")
    return FileResponse(VIP_SEARCH_HTML)


@router.get("/api/pages/privacy-policy")
def get_privacy_policy_page():
    if not PRIVACY_POLICY_HTML.exists():
        raise HTTPException(status_code=404, detail="Privacy policy not found")
    return FileResponse(PRIVACY_POLICY_HTML)


@router.get("/api/pages/user-agreement")
def get_user_agreement_page():
    if not USER_AGREEMENT_HTML.exists():
        raise HTTPException(status_code=404, detail="User agreement not found")
    return FileResponse(USER_AGREEMENT_HTML)


@router.get("/reports")
def get_reports_legacy(db: Session = Depends(get_db)):
    """Legacy endpoint — redirects users to /api/reports."""
    return {"message": "Use /api/reports instead"}


@router.api_route("/api/storage/object/{bucket}/{object_path:path}", methods=["POST", "PUT"])
async def upload_storage_object(bucket: str, object_path: str, request: Request):
    """Minimal storage-compatible upload endpoint for Flutter web/mobile clients."""
    content = await request.body()
    if not content:
        raise HTTPException(status_code=400, detail="Empty upload body")
    target = STORAGE_BASE / bucket / Path(object_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
    public_base = _resolve_public_base_url(request)
    public_url = f"{public_base}/api/storage/object/{bucket}/{object_path}"
    return {"Key": object_path, "bucket": bucket, "url": public_url}


@router.get("/api/storage/object/{bucket}/{object_path:path}")
async def get_storage_object(bucket: str, object_path: str):
    target = STORAGE_BASE / bucket / Path(object_path)
    if not target.exists() or not target.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    media_type = "application/octet-stream"
    suffix = target.suffix.lower()
    if suffix in {".jpg", ".jpeg"}:
        media_type = "image/jpeg"
    elif suffix == ".png":
        media_type = "image/png"
    elif suffix == ".webp":
        media_type = "image/webp"
    return Response(content=target.read_bytes(), media_type=media_type)


@router.get("/api/geo/reverse")
async def reverse_geocode_from_backend(lat: float, lon: float):
    """Backend-first reverse geocoder used by the mobile client."""
    address = await reverse_geocode(lat, lon)
    if not address:
        raise HTTPException(status_code=404, detail="Address not found")
    return {"address": address}


@router.post("/complaints")
@_complaint_limiter.limit("5/minute")
def create_complaint_from_mobile(report: dict, request: Request, db: Session = Depends(get_db)):
    """Create a complaint from the Flutter mobile app."""
    try:
        db_report = Report(
            title=report.get("title", ""),
            description=report.get("description"),
            lat=report.get("latitude"),
            lng=report.get("longitude"),
            address=report.get("address"),
            category=report.get("category", "other"),
            status=report.get("status", "open"),
        )
        db.add(db_report)
        db.commit()
        db.refresh(db_report)
        res = {
            "id": db_report.id,
            "title": db_report.title,
            "description": db_report.description,
            "latitude": float(db_report.lat) if db_report.lat is not None else None,
            "longitude": float(db_report.lng) if db_report.lng is not None else None,
            "address": db_report.address,
            "category": db_report.category,
            "status": db_report.status,
            "created_at": (
                db_report.created_at.isoformat() if db_report.created_at else None
            ),
        }

        # Reward system: 30 minutes of AI monitoring per submitted problem
        user_id = report.get("user_id")
        if user_id:
            from backend.models import User, VipSubscription
            from datetime import datetime, timedelta
            user = db.query(User).filter(User.id == user_id).first()
            if user and user.telegram_id:
                sub = db.query(VipSubscription).filter(VipSubscription.telegram_id == user.telegram_id).first()
                if not sub:
                    sub = VipSubscription(
                        telegram_id=user.telegram_id,
                        tier="free",
                        ai_minutes_total=60 + 30,
                        expires_at=datetime.utcnow() + timedelta(days=365)
                    )
                    db.add(sub)
                else:
                    sub.ai_minutes_total += 30
                db.commit()
                res["reward_message"] = "🎁 Вам начислено 30 минут ИИ-мониторинга за помощь городу! Спасибо за сообщение."

        return res
    except Exception as e:
        db.rollback()
        logger.error("Error creating complaint: %s", e)
        return {"success": False, "error": str(e)}


@router.post("/send-email")
async def send_email(payload: dict):
    """Send email via Resend from the Timeweb runtime."""
    resend_api_key = (os.getenv("RESEND_API_KEY") or "").strip()
    if not resend_api_key:
        return {"ok": False, "error": "RESEND_API_KEY is not configured"}

    to_email = (payload.get("to_email") or "").strip()
    to_name = (payload.get("to_name") or "").strip()
    subject = (payload.get("subject") or "").strip()
    body = (payload.get("body") or "").strip()
    from_name = (payload.get("from_name") or "Пульс города").strip()
    from_email = (os.getenv("RESEND_FROM_EMAIL") or "onboarding@resend.dev").strip()

    if not to_email or not subject or not body:
        return {"ok": False, "error": "to_email, subject and body are required"}

    to_field = f"{to_name} <{to_email}>" if to_name else to_email
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(
            "https://api.resend.com/emails",
            headers={
                "Authorization": f"Bearer {resend_api_key}",
                "Content-Type": "application/json",
            },
            json={
                "from": f"{from_name} <{from_email}>",
                "to": [to_field],
                "subject": subject,
                "html": body,
            },
        )

    if resp.status_code >= 400:
        return {"ok": False, "error": resp.text[:500]}
    return {"ok": True, "provider": "resend", "result": resp.json()}


@router.post("/api/collective-email")
async def trigger_collective_email(payload: dict):
    complaint_id = payload.get("complaint_id")
    if not complaint_id:
        raise HTTPException(status_code=400, detail="complaint_id is required")
    logger.info("Collective email trigger requested for complaint_id=%s", complaint_id)
    return {"ok": True, "queued": True, "complaint_id": complaint_id}


# ---------------------------------------------------------------------------
# RAG City Assistant
# ---------------------------------------------------------------------------
@router.post("/api/rag/ask")
async def rag_ask(request: Request):
    body = await request.json()
    question = body.get("question", "").strip()
    if not question:
        raise HTTPException(400, "question required")
    from services.rag_city_assistant import ask_city_question
    return await ask_city_question(question)


# ---------------------------------------------------------------------------
# Telegram Stars invoice (XTR payments)
# ---------------------------------------------------------------------------
@router.post("/api/stars/create-invoice")
async def create_stars_invoice(request: Request):
    """Create a Telegram Stars invoice link for subscription."""
    body = await request.json()
    plan = body.get("plan", "activist")

    # Stars pricing (Telegram Stars, not rubles)
    STAR_PLANS = {
        "activist": {"title": "Активист", "description": "Камеры 24/7, AI мониторинг", "amount": 150, "months": 1},
        "volunteer": {"title": "OSINT-Волонтёр", "description": "OSINT + AI 300ч + Mesh", "amount": 350, "months": 1},
    }

    if plan not in STAR_PLANS:
        raise HTTPException(400, "Invalid plan")

    p = STAR_PLANS[plan]

    bot_token = os.getenv("TG_BOT_TOKEN", "")
    if not bot_token:
        raise HTTPException(500, "Bot not configured")

    # Create invoice link via Bot API
    async with httpx.AsyncClient() as client:
        r = await client.post(
            f"https://api.telegram.org/bot{bot_token}/createInvoiceLink",
            json={
                "title": p["title"],
                "description": p["description"],
                "payload": f"stars_{plan}_{body.get('telegram_id', 'unknown')}",
                "provider_token": "",   # Empty for Stars
                "currency": "XTR",      # Telegram Stars currency code
                "prices": [{"label": p["title"], "amount": p["amount"]}],
            },
        )
        data = r.json()
        if data.get("ok"):
            return {"invoice_url": data["result"]}
        else:
            raise HTTPException(500, data.get("description", "Failed to create invoice"))


# ---------------------------------------------------------------------------
# Sentiment analysis
# ---------------------------------------------------------------------------
@router.post("/api/sentiment")
async def analyze_sentiment_endpoint(request: Request):
    body = await request.json()
    text = body.get("text", "").strip()
    if not text:
        raise HTTPException(400, "text required")
    from services.sentiment_service import analyze_sentiment
    return await analyze_sentiment(text)


# ---------------------------------------------------------------------------
# OCR (image → text)
# ---------------------------------------------------------------------------
@router.post("/api/ocr")
async def ocr_endpoint(request: Request):
    """Extract text from uploaded image."""
    from services.ocr_service import extract_text_from_image, is_available
    if not is_available():
        raise HTTPException(503, "OCR not available — install pytesseract")

    form = await request.form()
    file = form.get("file")
    if not file:
        raise HTTPException(400, "file required")

    import tempfile
    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        text = await extract_text_from_image(tmp_path)
        return {"text": text, "available": True}
    finally:
        os.unlink(tmp_path)
