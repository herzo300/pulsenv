# services/Backend/routers/storage.py
"""Static file serving and storage upload/download endpoints."""

import logging
import os
import re
from pathlib import Path
from urllib.parse import urlsplit

from fastapi import APIRouter, HTTPException, Request, Response

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["storage"])

# Whitelist для разрешённых расширений файлов
ALLOWED_UPLOAD_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".webm",
    ".pdf", ".txt", ".json", ".csv", ".zip",
}

# Паттерн для валидации object_path — только безопасные символы
_SAFE_PATH_PATTERN = re.compile(r'^[a-zA-Z0-9_\-./\\]+$')

ROOT = Path(__file__).resolve().parents[3]
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


def _sanitize_object_path(object_path: str) -> str:
    """Sanitize object_path to prevent path traversal attacks."""
    # Reject if contains path traversal sequences
    if ".." in object_path:
        raise HTTPException(status_code=400, detail="Invalid path: contains '..'")
    # Reject if doesn't match safe pattern
    if not _SAFE_PATH_PATTERN.match(object_path):
        raise HTTPException(status_code=400, detail="Invalid path: contains disallowed characters")
    # Normalize and verify the resolved path stays within STORAGE_BASE
    return object_path


def _validate_upload_extension(object_path: str) -> None:
    """Validate file extension against whitelist."""
    suffix = Path(object_path).suffix.lower()
    if suffix not in ALLOWED_UPLOAD_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"File type '{suffix or 'unknown'}' is not allowed. Allowed: {', '.join(sorted(ALLOWED_UPLOAD_EXTENSIONS))}",
        )


@router.get("/pages/vip-search")
def get_vip_search_page(request: Request):
    """Serve VIP/OSINT search HTML page (admin-only when OSINT features are enabled)."""
    from fastapi.responses import FileResponse

    from services.Backend.security import is_feature_enabled, require_admin_api_token

    if is_feature_enabled("ENABLE_OSINT") or is_feature_enabled("ENABLE_PERSON_SEARCH"):
        require_admin_api_token(request)

    if not VIP_SEARCH_HTML.exists():
        raise HTTPException(status_code=404, detail="VIP page not found")
    return FileResponse(VIP_SEARCH_HTML)


@router.get("/pages/privacy-policy")
def get_privacy_policy_page():
    """Serve privacy policy HTML page."""
    from fastapi.responses import FileResponse
    if not PRIVACY_POLICY_HTML.exists():
        raise HTTPException(status_code=404, detail="Privacy policy not found")
    return FileResponse(PRIVACY_POLICY_HTML)


@router.get("/pages/user-agreement")
def get_user_agreement_page():
    """Serve user agreement HTML page."""
    from fastapi.responses import FileResponse
    if not USER_AGREEMENT_HTML.exists():
        raise HTTPException(status_code=404, detail="User agreement not found")
    return FileResponse(USER_AGREEMENT_HTML)


@router.api_route("/storage/object/{bucket}/{object_path:path}", methods=["POST", "PUT"])
async def upload_storage_object(bucket: str, object_path: str, request: Request):
    """Upload file to local storage (compatible with Flutter web/mobile clients)."""
    from services.local_media_storage import ROOT as STORAGE_ROOT

    # Sanitize and validate path
    object_path = _sanitize_object_path(object_path)

    # Validate file extension
    _validate_upload_extension(object_path)

    content = await request.body()
    if not content:
        raise HTTPException(status_code=400, detail="Empty upload body")

    # Limit upload size to 50MB
    if len(content) > 50 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 50MB)")

    STORAGE_BASE = STORAGE_ROOT / "static" / "uploads"

    # Resolve and verify the target path stays within STORAGE_BASE
    target = (STORAGE_BASE / bucket / Path(object_path)).resolve()
    if not str(target).startswith(str(STORAGE_BASE.resolve())):
        raise HTTPException(status_code=400, detail="Invalid path: escapes storage directory")

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)

    public_base = _resolve_public_base_url(request)
    public_url = f"{public_base}/api/storage/object/{bucket}/{object_path}"
    return {"Key": object_path, "bucket": bucket, "url": public_url}


@router.get("/storage/object/{bucket}/{object_path:path}")
async def get_storage_object(bucket: str, object_path: str):
    """Download file from local storage."""
    from services.local_media_storage import ROOT as STORAGE_ROOT
    STORAGE_BASE = STORAGE_ROOT / "static" / "uploads"
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
