"""Local static media storage for the Timeweb runtime."""

from __future__ import annotations

import mimetypes
from pathlib import Path

from core.config import PUBLIC_API_BASE_URL

ROOT = Path(__file__).resolve().parents[2]
UPLOAD_DIR = ROOT / "static" / "uploads" / "complaints"


def save_binary(content: bytes, filename: str) -> str:
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    safe_name = Path(filename).name.replace(" ", "_")
    target = UPLOAD_DIR / safe_name
    target.write_bytes(content)
    relative_url = f"/static/uploads/complaints/{safe_name}"
    base = (PUBLIC_API_BASE_URL or "").rstrip("/")
    return f"{base}{relative_url}" if base else relative_url


def save_image(content: bytes, filename: str) -> str:
    if not Path(filename).suffix:
        guessed_ext = mimetypes.guess_extension("image/jpeg") or ".jpg"
        filename = f"{filename}{guessed_ext}"
    return save_binary(content, filename)
