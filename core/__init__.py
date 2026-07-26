"""Core package — lazy exports so optional deps (telethon) are not loaded at import."""

from __future__ import annotations

__all__ = [
    "claude_geoparse",
    "nominatim_geocode",
    "create_client",
    "register_handlers",
    "start",
]


def __getattr__(name: str):
    if name in ("claude_geoparse", "nominatim_geocode"):
        from core.geoparse import claude_geoparse, nominatim_geocode

        return claude_geoparse if name == "claude_geoparse" else nominatim_geocode
    if name in ("create_client", "register_handlers", "start"):
        from core.monitor import create_client, register_handlers, start

        return {
            "create_client": create_client,
            "register_handlers": register_handlers,
            "start": start,
        }[name]
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
