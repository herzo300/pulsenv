"""Text filtering: spam/ad detection and relevance checks."""

import re

from .config import AD_KEYWORDS, COMPLAINT_MARKERS, MIN_TEXT_LENGTH, RELEVANT_CATEGORIES


def is_ad_or_spam(text: str) -> bool:
    t = text.lower()
    ad_count = sum(1 for kw in AD_KEYWORDS if kw in t)
    if ad_count >= 1 and any(
        kw in t
        for kw in [
            "промокод",
            "розыгрыш",
            "казино",
            "букмекер",
            "гороскоп",
            "продаётся",
            "продается",
            "сдаётся",
            "сдается",
            "вакансия",
            "taplink",
        ]
    ):
        return True
    if ad_count >= 2:
        return True
    emoji_count = len(re.findall(r"[\U0001F300-\U0001F9FF]", text))
    if emoji_count > 10 and len(text) < 200:
        return True
    if text.count("#") > 5:
        return True
    return False


def has_complaint_markers(text: str) -> bool:
    t = text.lower()
    return any(m in t for m in COMPLAINT_MARKERS)


def is_relevant_message(text: str, category: str) -> bool:
    if len(text.strip()) < MIN_TEXT_LENGTH:
        return False
    if is_ad_or_spam(text):
        return False
    if category in RELEVANT_CATEGORIES:
        return True
    if has_complaint_markers(text):
        return True
    return False
