"""
Camera Dataset Auto-Collector Service.
Collects snapshot images and verified VLM/Watchdog annotations during live monitoring
to build an ongoing training dataset for local YOLO edge classifier fine-tuning.
"""

from __future__ import annotations

import hashlib
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

logger = logging.getLogger(__name__)

ROOT = Path(__file__).resolve().parent.parent
DATASET_DIR = ROOT / "data" / "camera_dataset"
IMAGES_DIR = DATASET_DIR / "images"
LABELS_DIR = DATASET_DIR / "labels"

# Ensure dataset directories exist
IMAGES_DIR.mkdir(parents=True, exist_ok=True)
LABELS_DIR.mkdir(parents=True, exist_ok=True)


def _utcnow_str() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")


def save_sample(
    camera_name: str,
    event_type: str,
    confidence: float,
    description: Optional[str],
    image_bytes: bytes,
    lat: Optional[float] = None,
    lng: Optional[float] = None,
) -> Optional[str]:
    """
    Save a verified camera incident snapshot into the training dataset.
    Returns the sample_id if saved, or None on error.
    """
    if not image_bytes or len(image_bytes) < 1000:
        return None

    try:
        timestamp = _utcnow_str()
        img_hash = hashlib.md5(image_bytes[:1024]).hexdigest()[:8]
        sample_id = f"{timestamp}_{event_type}_{img_hash}"

        img_path = IMAGES_DIR / f"{sample_id}.jpg"
        json_path = LABELS_DIR / f"{sample_id}.json"

        # 1. Save image file
        img_path.write_bytes(image_bytes)

        # 2. Save metadata JSON label
        meta = {
            "sample_id": sample_id,
            "camera_name": camera_name,
            "event_type": event_type,
            "confidence": float(confidence),
            "description": description or "",
            "lat": lat,
            "lng": lng,
            "captured_at": datetime.now(timezone.utc).isoformat(),
            "image_size_bytes": len(image_bytes),
        }
        json_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

        logger.info("📸 Saved dataset sample: %s (%s, conf=%.2f)", sample_id, event_type, confidence)
        return sample_id
    except Exception as e:
        logger.error("Dataset collector save error: %s", e)
        return None


def get_dataset_stats() -> Dict[str, Any]:
    """Get current training dataset statistics."""
    try:
        images = list(IMAGES_DIR.glob("*.jpg"))
        labels = list(LABELS_DIR.glob("*.json"))

        by_category: Dict[str, int] = {}
        total_bytes = 0

        for label_path in labels:
            try:
                data = json.loads(label_path.read_text(encoding="utf-8"))
                cat = data.get("event_type", "unknown")
                by_category[cat] = by_category.get(cat, 0) + 1
            except Exception:
                pass

        for img in images:
            total_bytes += img.stat().st_size

        return {
            "total_samples": len(images),
            "total_labels": len(labels),
            "dataset_size_mb": round(total_bytes / (1024 * 1024), 2),
            "by_category": by_category,
            "dataset_dir": str(DATASET_DIR),
        }
    except Exception as e:
        logger.error("get_dataset_stats error: %s", e)
        return {
            "total_samples": 0,
            "total_labels": 0,
            "dataset_size_mb": 0.0,
            "by_category": {},
            "error": str(e),
        }
