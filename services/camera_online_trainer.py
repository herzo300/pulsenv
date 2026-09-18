"""
Camera Online Fine-Tuning Engine.
Asynchronously trains local YOLO edge models on the accumulated camera dataset in background.
Exports fine-tuned models to ONNX and reloads inference without interrupting live camera monitoring.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import shutil
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict

logger = logging.getLogger(__name__)

ROOT = Path(__file__).resolve().parent.parent
DATASET_DIR = ROOT / "data" / "camera_dataset"
MODELS_DIR = ROOT / "models"
RUNS_DIR = ROOT / "data" / "runs"

MODELS_DIR.mkdir(parents=True, exist_ok=True)
RUNS_DIR.mkdir(parents=True, exist_ok=True)

_training_lock = threading.Lock()
_training_state: Dict[str, Any] = {
    "is_training": False,
    "current_epoch": 0,
    "total_epochs": 0,
    "last_trained_at": None,
    "total_training_runs": 0,
    "last_loss": None,
    "status": "idle",
}


def get_training_status() -> Dict[str, Any]:
    """Return current online training engine status."""
    with _training_lock:
        return dict(_training_state)


def _convert_dataset_to_yolo_yaml() -> Path:
    """Prepare YOLO data.yaml configuration from collected dataset."""
    yaml_path = DATASET_DIR / "data.yaml"
    
    classes = ["dump", "accident", "flood", "smoke", "animals"]
    yaml_content = f"""
path: {DATASET_DIR.as_posix()}
train: images
val: images
names:
  0: dump
  1: accident
  2: flood
  3: smoke
  4: animals
"""
    yaml_path.write_text(yaml_content.strip(), encoding="utf-8")
    return yaml_path


def run_fine_tuning_job(epochs: int = 15) -> Dict[str, Any]:
    """
    Run YOLOv8 fine-tuning job on dataset.
    This runs in a worker thread so live camera monitoring is never blocked.
    """
    global _training_state

    with _training_lock:
        if _training_state["is_training"]:
            return {"status": "busy", "message": "Training job is already in progress"}
        _training_state["is_training"] = True
        _training_state["status"] = "training"
        _training_state["total_epochs"] = epochs
        _training_state["current_epoch"] = 0

    start_time = time.time()
    logger.info("🏋️ Online Fine-Tuning started (%d epochs)...", epochs)

    try:
        from ultralytics import YOLO

        yaml_path = _convert_dataset_to_yolo_yaml()
        base_model_path = MODELS_DIR / "yolov8n.pt"

        if not base_model_path.exists():
            model = YOLO("yolov8n.pt")
            model.save(str(base_model_path))
        else:
            model = YOLO(str(base_model_path))

        run_name = f"online_run_{int(time.time())}"
        
        # Train model
        results = model.train(
            data=str(yaml_path),
            epochs=epochs,
            imgsz=320,
            batch=16,
            patience=5,
            name=run_name,
            project=str(RUNS_DIR),
            verbose=False,
        )

        # Export updated weights to ONNX for fast C++/Python inference
        best_pt = RUNS_DIR / run_name / "weights" / "best.pt"
        onnx_dest = MODELS_DIR / "yolov8n.onnx"

        if best_pt.exists():
            trained_yolo = YOLO(str(best_pt))
            trained_yolo.export(format="onnx", imgsz=320)
            exported_onnx = best_pt.with_suffix(".onnx")
            if exported_onnx.exists():
                shutil.copy(str(exported_onnx), str(onnx_dest))
                logger.info("✅ Exported updated ONNX model: %s", onnx_dest)

        elapsed = round(time.time() - start_time, 1)

        with _training_lock:
            _training_state["is_training"] = False
            _training_state["status"] = "completed"
            _training_state["last_trained_at"] = datetime.now(timezone.utc).isoformat()
            _training_state["total_training_runs"] += 1
            _training_state["last_elapsed_sec"] = elapsed

        logger.info("🎉 Online Fine-Tuning completed in %.1fs!", elapsed)
        return {"status": "completed", "elapsed_sec": elapsed}

    except Exception as e:
        logger.error("Online Fine-Tuning error: %s", e)
        with _training_lock:
            _training_state["is_training"] = False
            _training_state["status"] = f"error: {str(e)}"
        return {"status": "error", "error": str(e)}


def trigger_training_async(epochs: int = 15):
    """Trigger training in background thread."""
    thread = threading.Thread(target=run_fine_tuning_job, kwargs={"epochs": epochs}, daemon=True)
    thread.start()
    return {"status": "started", "message": f"Background training job launched ({epochs} epochs)"}
