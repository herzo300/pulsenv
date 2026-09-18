"""Admin session management: 2FA, rate limiting, session CRUD, device unbind."""

from __future__ import annotations

import os
import secrets
from datetime import timedelta
from typing import Any

from fastapi import HTTPException, status

from services.Backend.admin_metrics.models import AdminSessionLock
from services.Backend.admin_metrics.utils import (
    _as_utc,
    _hash_text,
    _isoformat,
    _now_ts,
    _utcnow,
)

# Session constants
ADMIN_SESSION_TTL_SECONDS = 900
ADMIN_SESSION_ROW_ID = "global"
ADMIN_CLAIM_RATE_LIMIT_WINDOW_SECONDS = 5 * 60
ADMIN_CLAIM_RATE_LIMIT_ATTEMPTS = 8
# Секрет задаётся ТОЛЬКО через env (или shared TG_2FA_PASSWORD).
# Дефолтного значения нет: без настройки админ-вход возвращает 503.
ADMIN_2FA_PASSWORD = (
    os.getenv("ADMIN_2FA_PASSWORD", "").strip()
    or os.getenv("TG_2FA_PASSWORD", "").strip()
)
ADMIN_REQUIRE_2FA = (os.getenv("ADMIN_REQUIRE_2FA") or "true").strip().lower() in {
    "1",
    "true",
    "yes",
    "on",
}


class AdminRuntimeStoreSessionMixin:
    """Mixin providing admin session and 2FA management."""

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        # In-memory rate limiting for admin login attempts
        self._admin_claim_attempts: dict[str, list[float]] = {}

    def _ensure_admin_2fa(self, two_factor_code: str | None) -> None:
        if not ADMIN_REQUIRE_2FA:
            return

        if not ADMIN_2FA_PASSWORD:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="ADMIN_2FA_PASSWORD is not configured",
            )

        candidate = (two_factor_code or "").strip()
        if not candidate:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="2FA code is required",
            )
        if not secrets.compare_digest(candidate, ADMIN_2FA_PASSWORD):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid 2FA code",
            )

    def _trim_claim_attempts(self, key: str, now_ts: float) -> list[float]:
        attempts = self._admin_claim_attempts.get(key, [])
        if not attempts:
            return []
        threshold = now_ts - ADMIN_CLAIM_RATE_LIMIT_WINDOW_SECONDS
        attempts = [ts for ts in attempts if ts >= threshold]
        self._admin_claim_attempts[key] = attempts
        return attempts

    def _assert_claim_rate_limit(self, keys: list[str]) -> None:
        now_ts = _now_ts()
        for key in keys:
            attempts = self._trim_claim_attempts(key, now_ts)
            if len(attempts) >= ADMIN_CLAIM_RATE_LIMIT_ATTEMPTS:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many invalid admin login attempts, try again later",
                )

    def _register_claim_failure(self, keys: list[str]) -> None:
        now_ts = _now_ts()
        for key in keys:
            attempts = self._trim_claim_attempts(key, now_ts)
            attempts.append(now_ts)
            self._admin_claim_attempts[key] = attempts

    def _clear_claim_attempts(self, keys: list[str]) -> None:
        for key in keys:
            self._admin_claim_attempts.pop(key, None)

    def claim_admin_session(
        self,
        *,
        device_id: str,
        two_factor_code: str | None,
        ip: str | None = None,
    ) -> dict[str, Any]:
        limiter_keys = [f"dev:{_hash_text(device_id)}"]
        if ip:
            limiter_keys.append(f"ip:{_hash_text(ip)}")

        with self._lock:
            self._assert_claim_rate_limit(limiter_keys)
            try:
                self._ensure_admin_2fa(two_factor_code)
            except HTTPException:
                self._register_claim_failure(limiter_keys)
                raise
            self._clear_claim_attempts(limiter_keys)

        token = secrets.token_urlsafe(32)
        device_hash = _hash_text(device_id)
        token_hash = _hash_text(token)
        now = _utcnow()
        expires_at = now + timedelta(seconds=ADMIN_SESSION_TTL_SECONDS)

        with self._lock:
            db = self._db()
            try:
                session_row = db.get(AdminSessionLock, ADMIN_SESSION_ROW_ID)
                if session_row is None:
                    session_row = AdminSessionLock(id=ADMIN_SESSION_ROW_ID)
                    db.add(session_row)
                    db.flush()

                # Allow taking over an active session from another device/emulator if the correct 2FA code is entered.
                # This prevents administrator lockouts when switching devices or on device ID changes.
                pass

                session_row.device_id_hash = device_hash
                session_row.session_token_hash = token_hash
                session_row.session_expires_at = expires_at
                session_row.last_seen_at = now
                session_row.updated_at = now
                db.commit()
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

        return {
            "token": token,
            "expires_at": _isoformat(expires_at),
            "ttl_seconds": ADMIN_SESSION_TTL_SECONDS,
        }

    def release_admin_session(self, *, device_id: str, token: str) -> None:
        with self._lock:
            db = self._db()
            try:
                session_row = db.get(AdminSessionLock, ADMIN_SESSION_ROW_ID)
                if session_row is None:
                    return
                if not self._is_valid_session_row(
                    session_row, device_id=device_id, token=token
                ):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Admin session is not owned by this device",
                    )
                session_row.session_token_hash = None
                session_row.session_expires_at = None
                session_row.last_seen_at = _utcnow()
                session_row.updated_at = _utcnow()
                db.commit()
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

    def validate_admin_session(self, *, device_id: str, token: str) -> None:
        with self._lock:
            db = self._db()
            try:
                session_row = db.get(AdminSessionLock, ADMIN_SESSION_ROW_ID)
                if session_row is None or not self._is_valid_session_row(
                    session_row,
                    device_id=device_id,
                    token=token,
                ):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Admin session is invalid or expired",
                    )
                session_row.session_expires_at = _utcnow() + timedelta(
                    seconds=ADMIN_SESSION_TTL_SECONDS
                )
                session_row.last_seen_at = _utcnow()
                session_row.updated_at = _utcnow()
                db.commit()
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

    def _is_valid_session_row(
        self,
        session_row: AdminSessionLock,
        *,
        device_id: str,
        token: str,
    ) -> bool:
        now = _utcnow()
        if not session_row.session_token_hash or not session_row.session_expires_at:
            return False
        if _as_utc(session_row.session_expires_at) <= now:
            return False
        return session_row.device_id_hash == _hash_text(
            device_id
        ) and session_row.session_token_hash == _hash_text(token)

    def unbind_device(self, *, device_id: str) -> dict[str, Any]:
        from services.Backend.admin_metrics.models import (
            AdminAccessPolicy,
            AdminRuntimeDevice,
        )

        device_id = device_id.strip()
        if not device_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="device_id is required",
            )

        with self._lock:
            db = self._db()
            try:
                device = db.get(AdminRuntimeDevice, device_id)
                policy = db.get(AdminAccessPolicy, device_id)
                if policy is not None:
                    db.delete(policy)
                if device is not None:
                    db.delete(device)

                released_session = False
                session_row = db.get(AdminSessionLock, ADMIN_SESSION_ROW_ID)
                if session_row and session_row.device_id_hash == _hash_text(device_id):
                    session_row.session_token_hash = None
                    session_row.session_expires_at = None
                    session_row.last_seen_at = _utcnow()
                    session_row.updated_at = _utcnow()
                    released_session = True

                db.commit()
                return {
                    "device_id": device_id,
                    "removed": bool(device is not None or policy is not None),
                    "released_admin_session": released_session,
                }
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()
