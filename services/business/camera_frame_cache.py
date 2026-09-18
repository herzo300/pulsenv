"""Camera frame caching utilities for City Pulse backend.

Avoids redundant ffmpeg requests by keeping local JPEGs on disk.
"""

from __future__ import annotations

import hashlib
import logging
import time
from pathlib import Path

logger = logging.getLogger(__name__)

# Base directory for camera VLM cache
CACHE_DIR = Path("data/vlm_cache")


def get_cache_path(camera_url: str) -> Path:
    """Generate a stable, unique filesystem path for a camera stream URL."""
    normalized = camera_url.strip().lower()
    url_hash = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
    return CACHE_DIR / f"{url_hash}.jpg"


def get_cached_frame(camera_url: str, max_age_seconds: int = 120) -> bytes | None:
    """Retrieve cached frame bytes if they are fresh enough."""
    try:
        path = get_cache_path(camera_url)
        if not path.exists():
            return None

        # Check modifications timestamp
        mtime = path.stat().st_mtime
        age = time.time() - mtime
        if age > max_age_seconds:
            logger.debug("Cache expired for camera URL (age: %.1fs)", age)
            return None

        logger.debug("Cache hit for camera URL (age: %.1fs)", age)
        return path.read_bytes()
    except Exception as exc:
        logger.warning("Failed to read cached frame: %s", exc)
        return None


def set_cached_frame(camera_url: str, frame_bytes: bytes) -> None:
    """Save captured frame bytes to local cache directory."""
    if not frame_bytes:
        return
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        path = get_cache_path(camera_url)
        path.write_bytes(frame_bytes)

        # Periodically trigger cache cleanups
        import random

        if random.random() < 0.05:
            clean_old_cache(max_age_seconds=600)
    except Exception as exc:
        logger.warning("Failed to write frame to cache: %s", exc)


def clean_old_cache(max_age_seconds: int = 600) -> None:
    """Delete JPEG files in cache directory older than max_age_seconds."""
    try:
        if not CACHE_DIR.exists():
            return
        now = time.time()
        removed_count = 0
        for item in CACHE_DIR.glob("*.jpg"):
            if item.is_file():
                if now - item.stat().st_mtime > max_age_seconds:
                    try:
                        item.unlink()
                        removed_count += 1
                    except OSError:
                        pass
        if removed_count > 0:
            logger.info("Cleaned %d stale items from frame cache", removed_count)
    except Exception as exc:
        logger.warning("Error running cache cleanup: %s", exc)
