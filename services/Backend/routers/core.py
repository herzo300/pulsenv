# services/Backend/routers/core.py — Root, health, categories, webhook, mobile complaint, email
"""
Core API routes: health checks, config, categories, complaints from mobile,
Telegram webhook receiver, and email sending.
"""

import logging
import os

import httpx
from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from backend.database import get_db
from backend.models import Report
from services.zai_service import CATEGORIES

logger = logging.getLogger(__name__)

router = APIRouter(tags=["core"])


@router.post("/webhook/telegram")
async def telegram_webhook(request: Request):
    """Receive Telegram webhook updates (requires WEBHOOK_BASE_URL in .env)."""
    try:
        from services.telegram_bot import bot, dp
        from aiogram.types import Update

        data = await request.json()
        update = Update.model_validate(data)
        await dp.feed_webhook_update(bot, update)
        return {"ok": True}
    except Exception as e:
        logger.error("Webhook error: %s", e)
        return {"ok": False, "error": str(e)}


@router.get("/")
def root():
    return {"status": "🚀 СообщиО API готов!"}


@router.get("/config")
def get_config():
    """Public config for the map: Supabase Realtime URL and anon key."""
    result: dict = {}
    url = (os.getenv("SUPABASE_URL") or "").strip()
    key = (os.getenv("SUPABASE_ANON_KEY") or "").strip()
    if url:
        result["supabaseUrl"] = url.rstrip("/")
    if key:
        result["supabaseAnonKey"] = key
    return result


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


@router.get("/reports")
def get_reports_legacy(db: Session = Depends(get_db)):
    """Legacy endpoint — redirects users to /api/reports."""
    return {"message": "Use /api/reports instead"}


@router.post("/complaints")
def create_complaint_from_mobile(report: dict, db: Session = Depends(get_db)):
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
        return {
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
    except Exception as e:
        db.rollback()
        logger.error("Error creating complaint: %s", e)
        return {"success": False, "error": str(e)}


@router.post("/send-email")
async def send_email(payload: dict):
    """Send email via Resend (fallback for Supabase Function)."""
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
