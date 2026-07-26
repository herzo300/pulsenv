from __future__ import annotations

import os
import secrets
from collections.abc import Iterable

from fastapi import HTTPException, Request, status


def parse_cors_origins(raw: str | None) -> list[str]:
    value = (raw or "").strip()
    if not value:
        public_origin = (os.getenv("PUBLIC_API_BASE_URL") or "").strip().rstrip("/")
        if not public_origin:
            # Fallback for non-web workers (monitoring, camera_probe)
            return ["http://localhost:8000"]
        return [public_origin]
    origins = [item.strip() for item in value.split(",") if item.strip()]
    if not origins:
        public_origin = (os.getenv("PUBLIC_API_BASE_URL") or "").strip().rstrip("/")
        if not public_origin:
            return ["http://localhost:8000"]
        return [public_origin]

    if os.getenv("PRODUCTION", "").lower() in ("1", "true", "yes"):
        for origin in origins:
            if origin == "*":
                raise RuntimeError(
                    "Wildcard CORS origin is not allowed in production"
                )
    return origins


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
    return any(
        secrets.compare_digest(token, valid.strip())
        for valid in valid_tokens
        if valid.strip()
    )


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


def validate_telegram_web_app_data(init_data: str, bot_token: str) -> bool:
    """
    Cryptographically verifies that the initData block was truly signed by Telegram.
    Prevents malicious actors from spoofing their user_id.
    """
    import hashlib
    import hmac
    from urllib.parse import parse_qsl

    try:
        parsed_data = dict(parse_qsl(init_data))
        if "hash" not in parsed_data:
            return False

        hash_val = parsed_data.pop("hash")
        data_check_string = "\n".join(
            f"{k}={v}" for k, v in sorted(parsed_data.items())
        )

        secret_key = hmac.new(
            b"WebAppData",
            bot_token.encode("utf-8"),
            hashlib.sha256
        ).digest()

        calculated_hash = hmac.new(
            secret_key,
            data_check_string.encode("utf-8"),
            hashlib.sha256
        ).hexdigest()

        return secrets.compare_digest(calculated_hash, hash_val)
    except Exception:
        return False
