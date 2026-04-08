"""
Sentiment Analysis Service — City mood detection from text.

Analyzes complaint text and Telegram messages to determine emotional tone.
Used for: daily mood reports, complaint urgency boosting, trend analysis.
"""

import logging
import os
from typing import Dict, Optional

logger = logging.getLogger(__name__)

# Lazy-loaded model
_model = None
_tokenizer = None
_model_loading = False
HAS_TORCH = False

try:
    import torch
    HAS_TORCH = True
except ImportError:
    logger.info("torch not available — sentiment will use keyword mode")


def _load_model():
    """Lazy-load ruBERT sentiment model on first use."""
    global _model, _tokenizer, _model_loading
    if _model is not None or _model_loading:
        return
    if not HAS_TORCH:
        return

    _model_loading = True
    try:
        from transformers import AutoTokenizer, AutoModelForSequenceClassification
        model_name = os.getenv("SENTIMENT_MODEL", "cointegrated/rubert-tiny-sentiment-balanced")
        logger.info("Loading sentiment model: %s", model_name)
        _tokenizer = AutoTokenizer.from_pretrained(model_name)
        _model = AutoModelForSequenceClassification.from_pretrained(model_name)
        _model.eval()
        logger.info("Sentiment model loaded successfully")
    except Exception as e:
        logger.warning("Failed to load sentiment model: %s", e)
    finally:
        _model_loading = False


LABELS = ["negative", "neutral", "positive"]

# Keyword-based sentiment (fast fallback)
_NEGATIVE_WORDS = {
    "ужас", "кошмар", "безобразие", "позор", "отвратительно", "невозможно",
    "опасно", "угроза", "разруш", "развал", "гниёт", "гнилой", "воняет",
    "задолбал", "достал", "бесит", "стыд", "хамство", "бардак", "катастроф",
    "сломан", "разбит", "грязь", "вонь", "мрак", "тьма", "плесень",
}
_POSITIVE_WORDS = {
    "спасибо", "молодцы", "отлично", "хорошо", "красиво", "чисто", "порядок",
    "ремонт сделали", "починили", "убрали", "исправили", "помогли", "быстро",
}


def _keyword_sentiment(text: str) -> Dict:
    """Fast keyword-based sentiment detection."""
    t = text.lower()
    neg_score = sum(1 for w in _NEGATIVE_WORDS if w in t)
    pos_score = sum(1 for w in _POSITIVE_WORDS if w in t)

    if neg_score > pos_score + 1:
        return {"label": "negative", "score": min(0.95, 0.5 + neg_score * 0.1), "method": "keyword"}
    elif pos_score > neg_score:
        return {"label": "positive", "score": min(0.95, 0.5 + pos_score * 0.1), "method": "keyword"}
    return {"label": "neutral", "score": 0.6, "method": "keyword"}


async def analyze_sentiment(text: str) -> Dict:
    """Analyze sentiment of text. Returns {label, score, method}.

    label: 'negative', 'neutral', 'positive'
    score: confidence 0.0-1.0
    method: 'rubert' or 'keyword'
    """
    if not text or len(text.strip()) < 3:
        return {"label": "neutral", "score": 0.5, "method": "skip"}

    # Try ruBERT first
    if HAS_TORCH and _model is None and not _model_loading:
        _load_model()

    if _model is not None and _tokenizer is not None:
        try:
            inputs = _tokenizer(text[:512], return_tensors="pt", truncation=True, padding=True)
            with torch.no_grad():
                outputs = _model(**inputs)
            probs = torch.nn.functional.softmax(outputs.logits, dim=-1)[0]
            idx = probs.argmax().item()
            return {
                "label": LABELS[idx],
                "score": round(probs[idx].item(), 3),
                "method": "rubert",
            }
        except Exception as e:
            logger.debug("ruBERT inference error: %s", e)

    return _keyword_sentiment(text)


async def get_city_mood(texts: list[str]) -> Dict:
    """Analyze aggregate mood from multiple texts.

    Returns: {mood: str, negative_pct, neutral_pct, positive_pct, total}
    """
    if not texts:
        return {"mood": "neutral", "negative_pct": 0, "neutral_pct": 100, "positive_pct": 0, "total": 0}

    counts = {"negative": 0, "neutral": 0, "positive": 0}
    for text in texts:
        result = await analyze_sentiment(text)
        counts[result["label"]] += 1

    total = len(texts)
    pcts = {k: round(v / total * 100, 1) for k, v in counts.items()}

    if pcts["negative"] > 50:
        mood = "тревожное"
    elif pcts["positive"] > 40:
        mood = "позитивное"
    else:
        mood = "нейтральное"

    return {
        "mood": mood,
        "negative_pct": pcts["negative"],
        "neutral_pct": pcts["neutral"],
        "positive_pct": pcts["positive"],
        "total": total,
    }


def is_available() -> bool:
    """Check if ML-based sentiment is available."""
    return HAS_TORCH
