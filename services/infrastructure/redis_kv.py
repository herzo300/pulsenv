"""Minimal Redis key-value helpers (optional — no-op when Redis unavailable)."""

from __future__ import annotations

import json
import logging
import os
from typing import Any

logger = logging.getLogger(__name__)

_client = None
_checked = False


def _redis():
    global _client, _checked
    if _checked:
        return _client
    _checked = True
    url = (os.getenv("REDIS_URL") or "").strip()
    if not url:
        host = os.getenv("REDIS_HOST", "localhost")
        port = os.getenv("REDIS_PORT", "6379")
        password = os.getenv("REDIS_PASSWORD", "")
        if password:
            url = f"redis://:{password}@{host}:{port}/0"
        else:
            url = f"redis://{host}:{port}/0"
    try:
        import redis

        _client = redis.from_url(url, decode_responses=True, socket_connect_timeout=1.5)
        _client.ping()
    except Exception as exc:
        logger.debug("Redis unavailable: %s", exc)
        _client = None
    return _client


def redis_get(key: str) -> str | None:
    client = _redis()
    if not client:
        return None
    try:
        return client.get(key)
    except Exception:
        return None


def redis_set(key: str, value: str, ttl_seconds: int = 604800) -> None:
    client = _redis()
    if not client:
        return
    try:
        client.setex(key, ttl_seconds, value)
    except Exception:
        pass


def redis_get_json(key: str) -> Any | None:
    raw = redis_get(key)
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def redis_set_json(key: str, value: Any, ttl_seconds: int = 604800) -> None:
    redis_set(key, json.dumps(value, ensure_ascii=False), ttl_seconds=ttl_seconds)
