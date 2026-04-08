from __future__ import annotations

import os
import secrets
from typing import Iterable

from fastapi import HTTPException, Request, status


def parse_cors_origins(raw: str | None) -> list[str]:
    value = (raw or "").strip()
    if not value:
        public_origin = (
            (os.getenv("PUBLIC_API_BASE_URL") or "").strip().rstrip("/")
            or "http://45.153.68.59"
        )
        return [public_origin]
    origins = [item.strip() for item in value.split(",") if item.strip()]
    return origins or [((os.getenv("PUBLIC_API_BASE_URL") or "").strip().rstrip("/") or "http://45.153.68.59")]


def _configured_tokens() -> list[str]:
    tokens: list[str] = []
    for env_name in ("ADMIN_API_TOKEN", "ADMIN_API_TOKENS"):
        raw = (os.getenv(env_name) or "").strip()
        if not raw:
            continue
        tokens.extend(token.strip() for token in raw.split(",") if token.strip())
    return tokens


def _extract_auth_token(request: Request) -> str:
    bearer = (request.headers.get("authorization") or "").strip()
    if bearer.lower().startswith("bearer "):
        return bearer.split(" ", 1)[1].strip()
    return (request.headers.get("x-admin-token") or "").strip()


def verify_token(candidate: str, valid_tokens: Iterable[str]) -> bool:
    token = candidate.strip()
    if not token:
        return False
    return any(secrets.compare_digest(token, valid.strip()) for valid in valid_tokens if valid.strip())


def require_admin_api_token(request: Request) -> None:
    configured = _configured_tokens()
    if not configured:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin API token is not configured",
        )

    provided = _extract_auth_token(request)
    if not verify_token(provided, configured):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin authorization required",
        )


def is_feature_enabled(flag_name: str, default: bool = False) -> bool:
    raw = (os.getenv(flag_name) or "").strip().lower()
    if not raw:
        return default
    return raw in {"1", "true", "yes", "on"}
