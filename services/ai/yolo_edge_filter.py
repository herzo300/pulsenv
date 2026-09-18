# services/yolo_edge_filter.py
"""
YOLOv11/v8 Edge Filter — мульти-модельная фильтрация кадров камер на CPU.
Оптимизирован для VPS с 2 ГБ RAM (Timeweb).

Модели:
  1. yolo11n.onnx / yolov8n.onnx — общая COCO (люди, авто, собаки)  ~12 МБ
  2. yolov8n_garbage.onnx — мусор/свалки (TACO dataset)              ~12 МБ
  3. yolov8n_fire_smoke.onnx — огонь/дым (DFire dataset)             ~12 МБ

Зависимости: onnxruntime, opencv-python-headless, supervision, numpy
НЕ требует: ultralytics, torch, GPU

NOTE: Custom classes 80-85 require a fine-tuned YOLOv11 model.
To create one:
  1. Collect 50-100 photos of each class from Nizhnevartovsk cameras
  2. Label with LabelImg/CVAT in YOLO format
  3. Train: yolo train model=yolo11n.pt data=nizhnevartovsk.yaml epochs=50
  4. Export: yolo export model=best.pt format=onnx
  5. Place as models/yolo11n_city.onnx
"""

import gc
import logging
import os
from pathlib import Path
from typing import Any

import numpy as np
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# ─── Конфигурация ───
def _default_models_dir() -> str:
    """Resolve /app/models from services/ai/yolo_edge_filter.py."""
    app_root = Path(__file__).resolve().parents[2]
    return str(app_root / "models")


MODELS_DIR: str = (os.getenv("YOLO_MODELS_DIR") or "").strip() or _default_models_dir()


def _resolve_model_path(env_name: str, default_filename: str) -> str:
    explicit = (os.getenv(env_name, "") or "").strip()
    local_candidate = Path(MODELS_DIR) / default_filename
    if explicit:
        explicit_path = Path(explicit)
        if explicit_path.exists():
            return str(explicit_path)
        remapped = Path(MODELS_DIR) / explicit_path.name
        if remapped.exists():
            logger.info("Using local model fallback for %s: %s", env_name, remapped)
            return str(remapped)
    return str(local_candidate)


def _resolve_main_model_path() -> str:
    """Find best available main YOLO model: YOLOv11 preferred, v8 fallback."""
    env_path = (os.getenv("YOLO_MODEL_PATH", "") or "").strip()
    if env_path:
        resolved = _resolve_model_path(
            "YOLO_MODEL_PATH",
            Path(env_path).name or "yolov8n.onnx",
        )
        if Path(resolved).exists():
            return resolved
    candidates = ["yolo11n.onnx", "yolov11n.onnx", "yolov8n.onnx"]
    for name in candidates:
        p = Path(MODELS_DIR) / name
        if p.exists():
            logger.info("Selected main YOLO model: %s", p)
            return str(p)
    # Default fallback (will be handled gracefully if missing)
    return str(Path(MODELS_DIR) / "yolo11n.onnx")


MODEL_PATH: str = _resolve_main_model_path()
GARBAGE_MODEL_PATH: str = _resolve_model_path(
    "YOLO_GARBAGE_MODEL_PATH",
    "yolov8n_garbage.onnx",
)
FIRE_SMOKE_MODEL_PATH: str = _resolve_model_path(
    "YOLO_FIRE_SMOKE_MODEL_PATH",
    "yolov8n_fire_smoke.onnx",
)

CONFIDENCE_THRESHOLD: float = float(os.getenv("YOLO_CONFIDENCE", "0.40"))
INPUT_SIZE: int = int(os.getenv("YOLO_INPUT_SIZE", "320"))
EDGE_FILTER_ENABLED: bool = os.getenv("EDGE_FILTER_ENABLED", "true").lower() == "true"

# ─── Классы COCO (общая модель) ───
COCO_ALERT_CLASSES: dict[int, str] = {
    0: "person",
    1: "bicycle",
    2: "car",
    3: "motorcycle",
    5: "bus",
    7: "truck",
    15: "cat",
    16: "dog",
}

# ─── Городские классы для мониторинга ───
# Standard COCO classes relevant for city monitoring
CITY_ALERT_CLASSES: dict[int, str] = {
    0: "person",  # People detection (crowds)
    1: "bicycle",  # Bicycle
    2: "car",  # Vehicles
    3: "motorcycle",  # Motorcycle
    5: "bus",  # Bus
    7: "truck",  # Truck
    16: "dog",  # Stray animals
    # Custom urban classes (requires fine-tuned model)
    80: "pothole",  # Выбоина на дороге
    81: "garbage_dump",  # Мусорная свалка
    82: "graffiti",  # Граффити/вандализм
    83: "snow_sidewalk",  # Нечищеный тротуар
    84: "broken_bench",  # Сломанная лавочка
    85: "trash_bin",  # Мусорный бак
}

# Alert thresholds for city monitoring
CITY_ALERT_THRESHOLDS: dict[str, dict[str, Any]] = {
    "crowd": {"class": 0, "min_count": 8, "label": "Скопление людей"},
    "stray_dogs": {"class": 16, "min_count": 3, "label": "Стая бродячих собак"},
    "traffic_jam": {"classes": [2, 5, 7], "min_count": 6, "label": "Затор на дороге"},
    "pothole": {"class": 80, "min_count": 1, "label": "Выбоина на дороге"},
    "garbage": {"class": 81, "min_count": 1, "label": "Несанкционированная свалка"},
    "graffiti": {"class": 82, "min_count": 1, "label": "Вандализм/граффити"},
    "snow": {"class": 83, "min_count": 1, "label": "Нечищеный тротуар"},
}

# ─── Пороги эскалации ───
CROWD_THRESHOLD: int = 6
DOG_PACK_THRESHOLD: int = 3
VEHICLE_CLUSTER_THRESHOLD: int = 3

# ─── Sessions (ленивая загрузка) ───
_sessions: dict[str, Any] = {}
_load_attempted: dict[str, bool] = {}


def _get_ort_options():
    """ONNX Runtime session options для 2 ГБ RAM."""
    import onnxruntime as ort

    opts = ort.SessionOptions()
    opts.intra_op_num_threads = 2
    opts.inter_op_num_threads = 1
    opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    opts.enable_mem_pattern = True
    opts.enable_cpu_mem_arena = False
    return opts


def _load_model(model_key: str, model_path: str):
    """Ленивая загрузка ONNX модели по ключу."""
    if model_key in _sessions:
        return _sessions[model_key]

    if _load_attempted.get(model_key):
        return None

    _load_attempted[model_key] = True

    if not os.path.exists(model_path):
        logger.debug("Model '%s' not found at %s — skipping", model_key, model_path)
        return None

    try:
        import onnxruntime as ort

        session = ort.InferenceSession(
            model_path,
            sess_options=_get_ort_options(),
            providers=["CPUExecutionProvider"],
        )
        _sessions[model_key] = session
        size_mb = os.path.getsize(model_path) / 1e6
        logger.info("✅ YOLO %s loaded: %s (%.1f MB)", model_key, model_path, size_mb)
        return session
    except Exception as e:
        logger.error("❌ YOLO %s load failed: %s", model_key, e)
        return None


def _preprocess(image_bytes: bytes) -> np.ndarray:
    """JPEG bytes → float32 tensor [1, 3, H, W]."""
    try:
        import cv2

        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("cv2.imdecode returned None")
        img = cv2.resize(img, (INPUT_SIZE, INPUT_SIZE), interpolation=cv2.INTER_LINEAR)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    except ImportError:
        from io import BytesIO

        from PIL import Image

        pil_img = Image.open(BytesIO(image_bytes)).convert("RGB")
        pil_img = pil_img.resize((INPUT_SIZE, INPUT_SIZE), Image.BILINEAR)
        img = np.array(pil_img)

    img = img.astype(np.float32) / 255.0
    img = np.transpose(img, (2, 0, 1))
    return np.expand_dims(img, axis=0)


def _postprocess(
    output: np.ndarray,
    conf_thresh: float,
    class_filter: dict[int, str] | None = None,
) -> list[dict[str, Any]]:
    """YOLOv8 ONNX output → список детекций."""
    predictions = output[0].T
    detections: list[dict[str, Any]] = []

    for pred in predictions:
        class_scores = pred[4:]
        class_id = int(np.argmax(class_scores))
        confidence = float(class_scores[class_id])

        if confidence < conf_thresh:
            continue
        if class_filter and class_id not in class_filter:
            continue

        cx, cy, w, h = pred[:4]
        class_name = (
            class_filter[class_id]
            if class_filter and class_id in class_filter
            else f"class_{class_id}"
        )
        detections.append(
            {
                "class_id": class_id,
                "class_name": class_name,
                "confidence": round(confidence, 3),
                "bbox": [float(cx - w / 2), float(cy - h / 2), float(w), float(h)],
            }
        )

    return detections


def _run_model(
    model_key: str,
    model_path: str,
    tensor: np.ndarray,
    conf_thresh: float,
    class_filter: dict[int, str] | None = None,
) -> list[dict]:
    """Run inference on a single model."""
    session = _load_model(model_key, model_path)
    if session is None:
        return []
    try:
        input_name = session.get_inputs()[0].name
        outputs = session.run(None, {input_name: tensor})
        return _postprocess(outputs[0], conf_thresh, class_filter)
    except Exception as e:
        logger.error("YOLO %s inference error: %s", model_key, e)
        return []


# ─── Фоновое вычитание ───
_bg_models: dict[str, Any] = {}
_MAX_BG_MODELS: int = 15


def _motion_ratio(image_bytes: bytes, camera_id: str) -> float:
    """MOG2 background subtraction → motion ratio 0.0–1.0."""
    try:
        import cv2

        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
        if img is None:
            return 0.0
        img = cv2.resize(img, (160, 120))
        img = cv2.GaussianBlur(img, (11, 11), 0)

        if camera_id not in _bg_models:
            if len(_bg_models) >= _MAX_BG_MODELS:
                oldest = next(iter(_bg_models))
                del _bg_models[oldest]
            _bg_models[camera_id] = cv2.createBackgroundSubtractorMOG2(
                history=50,
                varThreshold=50,
                detectShadows=False,
            )
        fg_mask = _bg_models[camera_id].apply(img)
        return float(np.count_nonzero(fg_mask)) / fg_mask.size
    except Exception:
        return 0.0


# ─── Supervision зонирование (опционально) ───
def _supervision_analyze(detections_list: list[dict], image_bytes: bytes) -> list[str]:
    """
    Расширенная аналитика через Roboflow Supervision:
    подсчёт объектов, зоны, heatmap.
    """
    extra_reasons = []
    try:
        import cv2
        import supervision as sv

        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None or not detections_list:
            return extra_reasons

        h, w = img.shape[:2]

        # Convert to Supervision Detections
        xyxy = []
        confs = []
        class_ids = []
        for d in detections_list:
            bx, by, bw, bh = d["bbox"]
            # Scale from INPUT_SIZE to original image
            sx, sy = w / INPUT_SIZE, h / INPUT_SIZE
            x1, y1 = bx * sx, by * sy
            x2, y2 = (bx + bw) * sx, (by + bh) * sy
            xyxy.append([x1, y1, x2, y2])
            confs.append(d["confidence"])
            class_ids.append(d["class_id"])

        if not xyxy:
            return extra_reasons

        sv_detections = sv.Detections(
            xyxy=np.array(xyxy),
            confidence=np.array(confs),
            class_id=np.array(class_ids),
        )

        # Зона нижней трети кадра (пешеходная зона / тротуар)
        bottom_zone = sv.PolygonZone(
            polygon=np.array([[0, h * 0.6], [w, h * 0.6], [w, h], [0, h]]),
        )
        in_zone = bottom_zone.trigger(sv_detections)
        zone_count = int(np.sum(in_zone)) if in_zone is not None else 0

        if zone_count >= 5:
            extra_reasons.append(f"crowded_zone_{zone_count}")

    except ImportError:
        pass
    except Exception as e:
        logger.debug("Supervision analysis error: %s", e)

    return extra_reasons


def check_city_alerts(detections: list[dict]) -> list[dict]:
    """Check detections against city-specific alert thresholds."""
    alerts = []
    class_counts: dict[int, int] = {}
    for det in detections:
        cls = det.get("class_id", det.get("class", -1))
        class_counts[cls] = class_counts.get(cls, 0) + 1

    for alert_type, config in CITY_ALERT_THRESHOLDS.items():
        if "classes" in config:
            total = sum(class_counts.get(c, 0) for c in config["classes"])
        else:
            total = class_counts.get(config["class"], 0)

        if total >= config["min_count"]:
            alerts.append(
                {
                    "type": alert_type,
                    "label": config["label"],
                    "count": total,
                    "severity": 3
                    if alert_type in ("pothole", "garbage", "stray_dogs")
                    else 2,
                }
            )

    return alerts


def analyze_frame(image_bytes: bytes, camera_id: str = "default") -> dict[str, Any]:
    """
    Мульти-модельный анализ кадра:
      1. COCO (люди, авто, собаки)
      2. Garbage (мусор, свалки) — если модель есть
      3. Fire/Smoke (огонь, дым) — если модель есть
      4. Motion detection (фоновое вычитание)
      5. Supervision zone analysis
    """
    if not EDGE_FILTER_ENABLED:
        return {
            "should_escalate": True,
            "reason": "edge_filter_disabled",
            "detections_count": 0,
            "summary": "",
        }

    # Проверка хотя бы основной модели
    main_session = _load_model("coco", MODEL_PATH)
    if main_session is None:
        return {
            "should_escalate": True,
            "reason": "model_unavailable",
            "detections_count": 0,
            "summary": "",
        }

    try:
        tensor = _preprocess(image_bytes)
    except Exception as e:
        logger.error("Preprocessing error: %s", e)
        return {
            "should_escalate": True,
            "reason": "preprocess_error",
            "detections_count": 0,
            "summary": "",
        }

    # ── Модель 1: COCO (люди, авто, собаки) ──
    coco_dets = _run_model(
        "coco", MODEL_PATH, tensor, CONFIDENCE_THRESHOLD, COCO_ALERT_CLASSES
    )

    # ── Модель 2: Мусор/свалки (TACO) ──
    garbage_dets = _run_model("garbage", GARBAGE_MODEL_PATH, tensor, 0.35)

    # ── Модель 3: Огонь/дым (DFire) ──
    fire_dets = _run_model("fire_smoke", FIRE_SMOKE_MODEL_PATH, tensor, 0.35)

    gc.collect()

    # ── Анализ результатов ──
    all_detections = coco_dets + garbage_dets + fire_dets
    reasons: list[str] = []
    parts: list[str] = []

    # COCO analysis
    people = [d for d in coco_dets if d["class_name"] == "person"]
    dogs = [d for d in coco_dets if d["class_name"] == "dog"]
    cats = [d for d in coco_dets if d["class_name"] == "cat"]
    animals = dogs + cats
    vehicles = [
        d for d in coco_dets if d["class_name"] in ("car", "truck", "bus", "motorcycle")
    ]

    # ==== PP-Human (Пешеходные атрибуты) ====
    pphuman_descs = []
    if people:
        try:
            import cv2

            from .pphuman_service import describe_person_for_bot, extract_attributes

            nparr = np.frombuffer(image_bytes, np.uint8)
            orig_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if orig_img is not None:
                h, w = orig_img.shape[:2]
                sx, sy = w / INPUT_SIZE, h / INPUT_SIZE

                for p in people:
                    bx, by, bw, bh = p["bbox"]
                    x1, y1 = int(bx * sx), int(by * sy)
                    x2, y2 = int((bx + bw) * sx), int((by + bh) * sy)

                    x1, y1 = max(0, x1), max(0, y1)
                    x2, y2 = min(w, x2), min(h, y2)

                    crop = orig_img[y1:y2, x1:x2]
                    if crop.size > 0:
                        attrs = extract_attributes(crop)
                        if attrs.get("status") == "success":
                            desc = describe_person_for_bot(attrs)
                            pphuman_descs.append(desc)
                            p["pphuman"] = attrs  # Прикрепляем атрибуты к BBox
        except Exception as e:
            logger.error("PPHuman error: %s", e)

    if len(people) >= CROWD_THRESHOLD:
        reasons.append(f"crowd_{len(people)}")
    if len(dogs) >= DOG_PACK_THRESHOLD:
        reasons.append(f"dog_pack_{len(dogs)}")
    if len(vehicles) >= VEHICLE_CLUSTER_THRESHOLD:
        bboxes = [d["bbox"] for d in vehicles]
        centers = [(b[0] + b[2] / 2, b[1] + b[3] / 2) for b in bboxes]
        xs, ys = [c[0] for c in centers], [c[1] for c in centers]
        spread = max(max(xs) - min(xs), max(ys) - min(ys)) if xs else 999
        if spread < INPUT_SIZE * 0.3:
            reasons.append(f"vehicle_cluster_{len(vehicles)}")

    if people:
        if pphuman_descs:
            parts.append(f"люди ({', '.join(pphuman_descs)})")
        else:
            parts.append(f"люди:{len(people)}")
    if dogs:
        parts.append(f"собаки:{len(dogs)}")
    if cats:
        parts.append(f"кошки:{len(cats)}")
    if vehicles:
        parts.append(f"транспорт:{len(vehicles)}")

    # Garbage analysis
    if garbage_dets:
        reasons.append(f"garbage_{len(garbage_dets)}")
        parts.append(f"мусор:{len(garbage_dets)}")

    # Fire/smoke analysis
    if fire_dets:
        fire_items = [d for d in fire_dets if "fire" in d.get("class_name", "").lower()]
        smoke_items = [
            d for d in fire_dets if "smoke" in d.get("class_name", "").lower()
        ]
        other_fire = [
            d for d in fire_dets if d not in fire_items and d not in smoke_items
        ]

        if fire_items:
            reasons.append(f"fire_{len(fire_items)}")
            parts.append(f"огонь:{len(fire_items)}")
        if smoke_items:
            reasons.append(f"smoke_{len(smoke_items)}")
            parts.append(f"дым:{len(smoke_items)}")
        if other_fire:
            reasons.append(f"fire_alert_{len(other_fire)}")
            parts.append(f"тревога:{len(other_fire)}")

    # Motion detection
    motion = _motion_ratio(image_bytes, camera_id)
    if motion > 0.35:
        reasons.append(f"high_motion_{motion:.0%}")
    if motion > 0.1:
        parts.append(f"движение:{motion:.0%}")

    # Supervision zone analysis
    sv_reasons = _supervision_analyze(all_detections, image_bytes)
    reasons.extend(sv_reasons)

    return {
        "should_escalate": len(reasons) > 0,
        "reason": ", ".join(reasons) if reasons else "normal",
        "detections_count": len(all_detections),
        "summary": "; ".join(parts) if parts else "сцена без объектов",
        "counts": {
            "people": len(people),
            "vehicles": len(vehicles),
            "animals": len(animals),
        }
    }


def get_filter_status() -> dict[str, Any]:
    """Статус всех моделей edge-фильтра."""
    models_status = {}
    for key, path in [
        ("coco", MODEL_PATH),
        ("garbage", GARBAGE_MODEL_PATH),
        ("fire_smoke", FIRE_SMOKE_MODEL_PATH),
    ]:
        models_status[key] = {
            "loaded": key in _sessions,
            "path": path,
            "exists": os.path.exists(path),
            "size_mb": round(os.path.getsize(path) / 1e6, 1)
            if os.path.exists(path)
            else 0,
        }

    return {
        "enabled": EDGE_FILTER_ENABLED,
        "input_size": INPUT_SIZE,
        "confidence_threshold": CONFIDENCE_THRESHOLD,
        "models": models_status,
        "bg_models_count": len(_bg_models),
    }
