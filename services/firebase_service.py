# services/firebase_service.py
"""
Firebase Realtime Database — real-time синхронизация жалоб.
Каждая жалоба из TG/VK мониторинга → Firebase RTDB → клиенты получают обновления.
REST API — не требует service account.
"""

import logging
import os
import uuid
from datetime import datetime
from typing import Any, Dict, Optional

import httpx
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# Firebase config
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "soobshio")
FIREBASE_API_KEY = os.getenv("FIREBASE_API_KEY", "")
# Используем Cloudflare Worker прокси (Firebase RTDB заблокирован по гео)
_PROXY_BASE = os.getenv("CLOUDFLARE_PROXY_URL", "https://anthropic-proxy.uiredepositionherzo.workers.dev")
FIREBASE_RTDB_URL = os.getenv(
    "FIREBASE_RTDB_URL",
    f"{_PROXY_BASE}/firebase",
)

_ready = False


def get_firestore():
    """Проверяет доступность Firebase"""
    if FIREBASE_RTDB_URL:
        return "RTDB"
    return None


async def push_complaint(complaint: Dict[str, Any]) -> Optional[str]:
    """
    Сохраняет жалобу в Firebase RTDB коллекцию 'complaints'.
    Клиенты с on('child_added') получат обновление в реальном времени.
    Возвращает document ID или None при ошибке.
    """
    if not FIREBASE_RTDB_URL:
        return None

    doc_id = str(uuid.uuid4())[:8] + "_" + datetime.utcnow().strftime("%H%M%S")

    doc_data = {
        "category": complaint.get("category", "Прочее"),
        "summary": (complaint.get("summary") or "")[:200],
        "description": (complaint.get("text") or "")[:2000],
        "address": complaint.get("address"),
        "lat": complaint.get("lat"),
        "lng": complaint.get("lng"),
        "source": complaint.get("source", "unknown"),
        "source_name": complaint.get("source_name", ""),
        "post_link": complaint.get("post_link", ""),
        "provider": complaint.get("provider", ""),
        "status": "open",
        "created_at": datetime.utcnow().isoformat(),
    }

    url = f"{FIREBASE_RTDB_URL}/complaints/{doc_id}.json"

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.put(url, json=doc_data)
            if r.status_code == 200:
                logger.info(f"🔥 Firebase RTDB: жалоба сохранена ({doc_id})")
                # Обновляем счётчик
                await _increment_stats(complaint.get("category", "Прочее"))
                return doc_id
            else:
                logger.error(f"Firebase RTDB error: {r.status_code} {r.text[:200]}")
                return None
    except Exception as e:
        logger.error(f"Firebase RTDB error: {e}")
        return None


async def _increment_stats(category: str):
    """Обновляет real-time статистику"""
    url = f"{FIREBASE_RTDB_URL}/stats/realtime.json"
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            # Читаем текущие значения
            r = await client.get(url)
            current = r.json() if r.status_code == 200 and r.text != "null" else {}

            total = (current.get("total_complaints") or 0) + 1
            by_cat = current.get("by_category") or {}
            by_cat[category] = (by_cat.get(category) or 0) + 1

            # Записываем обновлённые
            await client.put(url, json={
                "total_complaints": total,
                "by_category": by_cat,
                "last_updated": datetime.utcnow().isoformat(),
            })
    except Exception as e:
        logger.debug(f"Stats update error: {e}")


async def get_recent_complaints(limit: int = 50) -> list:
    """Получает последние жалобы из Firebase RTDB"""
    if not FIREBASE_RTDB_URL:
        return []

    url = f'{FIREBASE_RTDB_URL}/complaints.json'
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(url)
            if r.status_code == 200 and r.text != "null":
                data = r.json()
                results = []
                for doc_id, doc_data in data.items():
                    doc_data["id"] = doc_id
                    results.append(doc_data)
                return sorted(results, key=lambda x: x.get("created_at", ""), reverse=True)
            return []
    except Exception as e:
        logger.error(f"Firebase read error: {e}")
        return []


async def update_complaint_status(doc_id: str, status: str) -> bool:
    """Обновляет статус жалобы"""
    if not FIREBASE_RTDB_URL:
        return False

    url = f"{FIREBASE_RTDB_URL}/complaints/{doc_id}.json"
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.patch(url, json={
                "status": status,
                "updated_at": datetime.utcnow().isoformat(),
            })
            return r.status_code == 200
    except Exception as e:
        logger.error(f"Firebase update error: {e}")
        return False
