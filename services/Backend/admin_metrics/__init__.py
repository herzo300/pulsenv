"""Admin metrics package — re-exports for backward compatibility.

This package refactors the former monolithic admin_metrics.py (1338 lines) into:
- models.py      — 7 SQLAlchemy model classes
- utils.py       — helper functions + constants
- store.py       — AdminRuntimeStore core (init, recording, policy, serialization)
- camera.py      — camera catalog + probing mixin
- session.py     — 2FA, rate limiting, session CRUD, device unbind mixin
- stats.py       — snapshot, time series, traffic aggregation mixin

Public API (backward compatible):
- metrics_store       — singleton instance
- require_admin_session — FastAPI dependency
- extract_client_ip   — utility
- extract_device_id   — utility
"""

from __future__ import annotations

from fastapi import Request

# Import mixins
from services.Backend.admin_metrics.camera import AdminRuntimeStoreCameraMixin
from services.Backend.admin_metrics.session import AdminRuntimeStoreSessionMixin
from services.Backend.admin_metrics.stats import AdminRuntimeStoreStatsMixin

# Import base store
from services.Backend.admin_metrics.store import (
    AdminRuntimeStore as _AdminRuntimeStoreBase,
)

# Import utilities
from services.Backend.admin_metrics.utils import extract_client_ip, extract_device_id


class AdminRuntimeStore(
    AdminRuntimeStoreSessionMixin,
    AdminRuntimeStoreCameraMixin,
    AdminRuntimeStoreStatsMixin,
    _AdminRuntimeStoreBase,
):
    """Complete admin runtime store with all mixins."""

    pass


# Singleton instance
metrics_store = AdminRuntimeStore()


def require_admin_session(request: Request) -> str:
    """FastAPI dependency that validates admin bearer token session.

    Только реальные сессии из metrics_store: создание через 2FA-логин,
    проверка SHA-256 хэша токена, TTL и привязки к устройству.
    """
    auth_header = request.headers.get("authorization", "").strip()
    if not auth_header.lower().startswith("bearer "):
        from fastapi import HTTPException, status

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin bearer token is required",
        )
    token = auth_header.split(" ", 1)[1].strip()
    if not token:
        from fastapi import HTTPException, status

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin bearer token is required",
        )

    device_id = extract_device_id(request)
    metrics_store.validate_admin_session(device_id=device_id, token=token)
    return device_id


__all__ = [
    "metrics_store",
    "require_admin_session",
    "extract_client_ip",
    "extract_device_id",
    "AdminRuntimeStore",
]
