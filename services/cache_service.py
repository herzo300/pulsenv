# services/cache_service.py
"""
Lightweight TTL cache for categories.
Uses the canonical CATEGORIES list from zai_service as the source of truth.
"""

from typing import Any, Dict, List

from cachetools import TTLCache

# Cache with 10-minute TTL
_category_cache: TTLCache = TTLCache(maxsize=1, ttl=600)


def get_categories_cached() -> List[Dict[str, Any]]:
    """Return cached list of categories (source: zai_service.CATEGORIES)."""
    if "categories" in _category_cache:
        return _category_cache["categories"]

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

    _category_cache["categories"] = categories
    return categories


def invalidate_categories_cache():
    """Invalidate the categories cache."""
    if "categories" in _category_cache:
        del _category_cache["categories"]
