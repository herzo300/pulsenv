# services/cache_service.py
"""
Lightweight TTL cache for categories.
Uses the canonical CATEGORIES list from zai_service as the source of truth.
"""

from typing import Any

_categories_cached: list[dict[str, Any]] | None = None


def get_categories_cached() -> list[dict[str, Any]]:
    """Return cached list of categories (source: zai_service.CATEGORIES)."""
    global _categories_cached
    if _categories_cached is not None:
        return _categories_cached

    from services.zai_service import CATEGORIES

    categories = [
        {
            "id": cat[:4] if len(cat) >= 4 else cat,
            "name": cat,
            "icon": "•",
            "color": "#818CF8",
        }
        for cat in CATEGORIES
    ]

    _categories_cached = categories
    return categories


def invalidate_categories_cache():
    """Invalidate the categories cache."""
    global _categories_cached
    _categories_cached = None
