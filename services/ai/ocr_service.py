"""
OCR Service — Tesseract-based text recognition for city complaint images.

Extracts text from photos of: address plates, documents, utility bills,
road signs, license plates. Used as a preprocessing step before AI analysis.
"""

import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

# Try to import pytesseract, gracefully degrade if not available
try:
    import pytesseract
    from PIL import Image

    HAS_TESSERACT = True
    # Windows path
    if os.name == "nt":
        tess_path = os.getenv(
            "TESSERACT_PATH", r"C:\Program Files\Tesseract-OCR\tesseract.exe"
        )
        if os.path.exists(tess_path):
            pytesseract.pytesseract.tesseract_cmd = tess_path
    logger.info("Tesseract OCR initialized")
except ImportError:
    HAS_TESSERACT = False
    logger.warning(
        "pytesseract not installed — OCR disabled. Install: pip install pytesseract Pillow"
    )


async def extract_text_from_image(
    image_path: str, lang: str = "rus+eng"
) -> str | None:
    """Extract text from image using Tesseract OCR.

    Args:
        image_path: Path to image file
        lang: Tesseract language (rus+eng for Russian+English)

    Returns:
        Extracted text or None if OCR unavailable
    """
    if not HAS_TESSERACT:
        return None

    try:
        img = Image.open(image_path)
        # Optimize for street signs and address plates
        text = pytesseract.image_to_string(img, lang=lang, config="--psm 6")
        text = text.strip()
        if text:
            logger.info(
                "OCR extracted %d chars from %s", len(text), Path(image_path).name
            )
        return text if text else None
    except Exception as e:
        logger.warning("OCR error on %s: %s", image_path, e)
        return None


async def extract_address_from_image(image_path: str) -> str | None:
    """Try to extract a street address from an image of a building/sign."""
    text = await extract_text_from_image(image_path)
    if not text:
        return None

    import re

    # Common Russian address patterns
    patterns = [
        r"(?:ул(?:ица|\.)?)\s*([А-Яа-яЁё\s]+?)\s*,?\s*(?:д(?:ом)?\.?\s*)?(\d+\s*[а-яА-Я]?)",
        r"(?:пр(?:оспект|\.)?)\s*([А-Яа-яЁё\s]+?)\s*,?\s*(?:д(?:ом)?\.?\s*)?(\d+\s*[а-яА-Я]?)",
        r"(?:пер(?:еулок|\.)?)\s*([А-Яа-яЁё\s]+?)\s*,?\s*(?:д(?:ом)?\.?\s*)?(\d+\s*[а-яА-Я]?)",
    ]

    for pat in patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            street = m.group(1).strip()
            building = m.group(2).strip()
            addr = f"ул. {street}, {building}"
            logger.info("OCR address detected: %s", addr)
            return addr

    return None


def is_available() -> bool:
    """Check if OCR is available."""
    return HAS_TESSERACT
