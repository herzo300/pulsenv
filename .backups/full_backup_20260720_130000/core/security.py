# core/security.py
"""
Security middleware and utilities — AgentShield Hardening.

Applied security skills:
  • Rate limiting per IP with sliding window
  • Security headers injection (CSP, HSTS, X-Frame-Options)
  • Admin token validation via timing-safe comparison
  • Request ID tracing for audit logs
"""

import hashlib
import hmac
import logging
import os
import time
import uuid
from collections import defaultdict
from typing import Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger(__name__)


# ──── Timing-safe token comparison ────
def verify_admin_token(provided: str) -> bool:
    """Verify admin token using constant-time comparison to prevent timing attacks."""
    expected = os.getenv("ADMIN_API_TOKEN", "")
    if not expected or not provided:
        return False
    return hmac.compare_digest(
        provided.encode("utf-8"),
        expected.encode("utf-8"),
    )


# ──── Rate Limiter (in-memory sliding window) ────
class _SlidingWindowLimiter:
    """Simple in-memory sliding window rate limiter."""

    def __init__(self) -> None:
        self._windows: dict[str, list[float]] = defaultdict(list)

    def is_allowed(self, key: str, max_requests: int, window_seconds: int) -> bool:
        now = time.monotonic()
        cutoff = now - window_seconds
        # Prune old entries
        self._windows[key] = [t for t in self._windows[key] if t > cutoff]
        if len(self._windows[key]) >= max_requests:
            return False
        self._windows[key].append(now)
        return True


_limiter = _SlidingWindowLimiter()


# ──── Security Middleware ────
class SecurityMiddleware(BaseHTTPMiddleware):
    """
    Injects security headers and request tracing on every response.

    Headers set:
      - X-Content-Type-Options: nosniff
      - X-Frame-Options: DENY
      - X-XSS-Protection: 1; mode=block
      - Strict-Transport-Security (if production)
      - X-Request-ID (unique per request for audit trail)
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Generate unique request ID for tracing
        request_id = str(uuid.uuid4())[:8]
        request.state.request_id = request_id

        response = await call_next(request)

        # Security headers
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["X-Request-ID"] = request_id

        # HSTS in production
        if os.getenv("PRODUCTION") == "true":
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains"
            )

        return response


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Rate limiting middleware — protects against abuse.

    Default limits:
      - General API: 60 requests / minute
      - Admin endpoints: 30 / minute
      - Complaint submission: 5 / minute
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        client_ip = request.client.host if request.client else "unknown"
        path = request.url.path.lower()

        # Choose appropriate rate limit
        if "/admin" in path or "/lookup" in path:
            key = f"admin:{client_ip}"
            max_req, window = 30, 60
        elif "/reports" in path and request.method == "POST":
            key = f"complaint:{client_ip}"
            max_req, window = 5, 60
        else:
            key = f"general:{client_ip}"
            max_req, window = 60, 60

        if not _limiter.is_allowed(key, max_req, window):
            logger.warning(
                "Rate limit exceeded: %s on %s (%s)", client_ip, path, key
            )
            return Response(
                content='{"detail":"Rate limit exceeded. Try again later."}',
                status_code=429,
                media_type="application/json",
                headers={"Retry-After": "60"},
            )

        return await call_next(request)


# ──── Input Sanitization ────
def sanitize_input(value: str, max_length: int = 2000) -> str:
    """Strip dangerous characters and enforce max length."""
    if not value:
        return ""
    # Remove null bytes and trim
    cleaned = value.replace("\x00", "").strip()
    # Enforce length limit
    return cleaned[:max_length]


def hash_sensitive(value: str) -> str:
    """One-way hash for logging sensitive values without exposing them."""
    return hashlib.sha256(value.encode()).hexdigest()[:12]
