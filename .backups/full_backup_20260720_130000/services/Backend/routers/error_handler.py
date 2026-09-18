# services/Backend/routers/error_handler.py
"""
Unified error handling utilities for all API routers.

Usage:
    from services.Backend.routers.error_handler import api_error

    @router.get("/something")
    async def get_something():
        try:
            result = do_something()
            return {"data": result}
        except Exception as e:
            return api_error("internal_error", "Описание ошибки", status=500)
"""

import logging
from typing import Any

logger = logging.getLogger(__name__)


def api_error(
    code: str,
    detail: str,
    status: int = 500,
    data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """
    Return a standardized error response.

    Args:
        code: Machine-readable error code (e.g. "not_found", "invalid_request")
        detail: Human-readable error message in Russian
        status: HTTP status code (default 500)
        data: Optional additional context

    Returns:
        Dict with error response structure
    """
    response = {
        "success": False,
        "error": {
            "code": code,
            "detail": detail,
        },
    }
    if data:
        response["error"]["data"] = data
    return response


def api_success(data: dict[str, Any], message: str | None = None) -> dict[str, Any]:
    """
    Return a standardized success response.

    Args:
        data: Response data
        message: Optional success message

    Returns:
        Dict with success response structure
    """
    response = {"success": True, "data": data}
    if message:
        response["message"] = message
    return response
