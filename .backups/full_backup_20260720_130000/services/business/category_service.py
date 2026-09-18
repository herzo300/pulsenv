"""Shared public report category normalization."""

from __future__ import annotations

from typing import Any

CATEGORY_LABELS = {
    "roads": "Дороги",
    "housing": "ЖКХ",
    "improvement": "Благоустройство",
    "lighting": "Освещение",
    "transport": "Транспорт",
    "ecology": "Экология",
    "safety": "Безопасность",
    "parking": "Парковки",
    "events": "Мероприятие",
    "animals": "Животные",
    "items": "Вещи",
    "other": "Прочее",
}


def normalize_category(value: Any) -> str:
    raw = str(value or "").strip()
    if not raw:
        return CATEGORY_LABELS["other"]
    lower = raw.lower()
    aliases = {
        "road": "roads",
        "roads": "roads",
        "дороги": "roads",
        "дтп": "roads",
        "жкх": "housing",
        "housing": "housing",
        "благоустройство": "improvement",
        "lighting": "lighting",
        "освещение": "lighting",
        "transport": "transport",
        "транспорт": "transport",
        "ecology": "ecology",
        "экология": "ecology",
        "security": "safety",
        "safety": "safety",
        "безопасность": "safety",
        "parking": "parking",
        "парковки": "parking",
        "мероприятие": "events",
        "мероприятия": "events",
        "event": "events",
        "events": "events",
        "животные": "animals",
        "animals": "animals",
        "потеряно животное": "animals",
        "найдено животное": "animals",
        "вещи": "items",
        "items": "items",
        "потеряна вещь": "items",
        "найдена вещь": "items",
        "прочее": "other",
        "other": "other",
    }
    if lower in aliases:
        return CATEGORY_LABELS[aliases[lower]]

    # Composite labels from AI/monitoring: "ЖКХ/Двор", "Дороги и тротуары", etc.
    substring_aliases = (
        ("дорог", "roads"),
        ("тротуар", "roads"),
        ("дтп", "roads"),
        ("жкх", "housing"),
        ("двор", "housing"),
        ("благоустрой", "improvement"),
        ("освещ", "lighting"),
        ("транспорт", "transport"),
        ("эколог", "ecology"),
        ("безопас", "safety"),
        ("животн", "animals"),
        ("собак", "animals"),
        ("кошк", "animals"),
        ("вещ", "items"),
        ("потерян", "items"),
        ("найден", "items"),
        ("пропал", "items"),
        ("сбежа", "items"),
        ("убежа", "items"),
        ("торгов", "other"),
        ("снег", "other"),
        ("налед", "other"),
        ("медиц", "other"),
        ("образован", "other"),
        ("мероприят", "events"),
    )
    for hint, slug in substring_aliases:
        if hint in lower:
            return CATEGORY_LABELS[slug]

    return raw


def categorize_text(text: str) -> str:
    lower = text.lower()
    if any(
        word in lower
        for word in (
            "концерт",
            "выстав",
            "спектак",
            "фестив",
            "соревнован",
            "ярмарк",
            "мастер-класс",
        )
    ):
        return CATEGORY_LABELS["events"]
    if any(
        word in lower
        for word in ("дтп", "авари", "столкн", "дорог", "проезд", "перекры")
    ):
        return CATEGORY_LABELS["roads"]
    if any(
        word in lower
        for word in ("жкх", "тепло", "отоплен", "вода", "подъезд", "лифт")
    ):
        return CATEGORY_LABELS["housing"]
    if any(word in lower for word in ("мусор", "свалк", "уборк", "гряз")):
        return CATEGORY_LABELS["improvement"]
    if any(word in lower for word in ("свет", "освещ", "фонар", "светофор")):
        return CATEGORY_LABELS["lighting"]
    if any(word in lower for word in ("парк", "сквер", "площадк", "контейнер")):
        return CATEGORY_LABELS["improvement"]
    return CATEGORY_LABELS["other"]
