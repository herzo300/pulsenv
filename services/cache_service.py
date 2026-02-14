from typing import Dict, Any
from cachetools import TTLCache

# Кэш категорий (10 минут)
_category_cache = TTLCache(maxsize=1, ttl=600)

def get_categories_cached() -> list[Dict[str, Any]]:
    """Возвращает закэшированный список категорий"""
    if "categories" in _category_cache:
        return _category_cache["categories"]
    
    categories = [
        {
            "id": cat[:4] if len(cat) >= 4 else cat,
            "name": cat,
            "icon": "•",
            "color": "#818CF8"
        }
        for cat in [
            "Дороги и ямы",
            "Освещение",
            "ЖКХ и коммунальные услуги",
            "Транспорт",
            "Мусор и санитария",
            "Зеленые зоны",
            "Парки и скверы",
            "Образование",
            "Медицина",
            "Безопасность",
            "Прочее"
        ]
    ]
    
    _category_cache["categories"] = categories
    return categories

def invalidate_categories_cache():
    """Инвалидирует кэш категорий"""
    if "categories" in _category_cache:
        del _category_cache["categories"]
