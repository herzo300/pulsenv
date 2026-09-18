import logging
import os
from pathlib import Path
from typing import Any

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# Конфигурация модели
MODELS_DIR = Path(__file__).parent.parent / "models"
MODEL_PATH = os.getenv("PPHUMAN_MODEL_PATH", str(MODELS_DIR / "pphuman_attribute.onnx"))

# PP-Human использует фиксированный размер входа [1, 3, 256, 192] (H=256, W=192)
INPUT_SIZE = (192, 256)

# Нормализация ImageNet (используется в Paddle)
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

# PP-Human предсказывает 26 атрибутов в одном векторе
# Структура индексов для официальной модели PP-Human (PULC Pedestrian Attribute):
ATTR_MAP = {
    # 0: Gender
    "gender": {0: "Женщина", 1: "Мужчина", "threshold": 0.5},
    # 1: Age
    "age": {2: "Младше 18", 3: "18-60 лет", 4: "Старше 60", "threshold": 0.5},
    # Direction
    "direction": {5: "Спереди", 6: "Сбоку", 7: "Сзади", "threshold": 0.5},
    # Accessories (индексы 8-13)
    "accessories": {
        8: "Очки",
        9: "Головной убор",
        10: "Маска",
        11: "Рюкзак",
        12: "Сумка на плече",
        13: "Ручная сумка",
    },
    # Upper/Lower wear (индексы 14-17)
    "clothing_type": {
        14: "Длинный рукав",
        15: "Короткий рукав",
        16: "Штаны/брюки",
        17: "Шорты",
    },
    # Верх цвет (18-28) и Низ цвет (29-39) - упрощенно для UI
    "upper_color": {
        # Индексы примерные для разных версий, берем базовые как True/False
        # Обычно это работает через argmax по группам категорий.
    },
}

# Массив всех названий атрибутов для удобства (по официальной документации PULC PAR)
ATTR_NAMES = [
    "Gender_Female",
    "Gender_Male",
    "Age_Under18",
    "Age_18to60",
    "Age_Over60",
    "Dir_Front",
    "Dir_Side",
    "Dir_Back",
    "Acc_Glasses",
    "Acc_Hat",
    "Acc_Mask",
    "Bag_Backpack",
    "Bag_Shoulder",
    "Bag_Hand",
    "Upper_LongSleeve",
    "Upper_ShortSleeve",
    "Lower_Trouser",
    "Lower_ShortSkirt",
    # Цвета верха и низа идут дальше в векторе (зависит от версии датасета PA-100K/Market)
]

_session = None
_load_attempted = False


def _load_model():
    global _session, _load_attempted
    if _session is not None:
        return _session
    if _load_attempted:
        return None

    _load_attempted = True
    if not os.path.exists(MODEL_PATH):
        logger.warning(f"⚠️ PP-Human model not found at {MODEL_PATH}")
        return None

    try:
        import onnxruntime as ort

        opts = ort.SessionOptions()
        opts.intra_op_num_threads = 1
        opts.inter_op_num_threads = 1
        opts.enable_cpu_mem_arena = False

        _session = ort.InferenceSession(
            MODEL_PATH, sess_options=opts, providers=["CPUExecutionProvider"]
        )
        logger.info(f"✅ PP-Human ONNX loaded: {MODEL_PATH}")
        return _session
    except Exception as e:
        logger.error(f"❌ PP-Human load failed: {e}")
        return None


def _preprocess(crop_img: np.ndarray) -> np.ndarray:
    """Нормализация и ресайз вырезанного фрагмента с человеком."""
    img = cv2.resize(crop_img, INPUT_SIZE, interpolation=cv2.INTER_LINEAR)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    img = img.astype(np.float32) / 255.0
    img = (img - MEAN) / STD

    img = np.transpose(img, (2, 0, 1))  # HWC -> CHW
    return np.expand_dims(img, axis=0)  # NCHW


def sigmoid(x):
    return 1 / (1 + np.exp(-x))


def extract_attributes(crop_img: np.ndarray) -> dict[str, Any]:
    """
    Анализ атрибутов (одежда, пол, рюкзак) по вырезанному фото человека.
    Возвращает удобочитаемый словарь атрибутов для телеграма/БД.
    """
    session = _load_model()
    if session is None or crop_img is None or crop_img.size == 0:
        return {"status": "error", "reason": "model_missing_or_bad_crop"}

    try:
        tensor = _preprocess(crop_img)
        input_name = session.get_inputs()[0].name

        # Получаем логиты. Shape: [1, 26] (обычно)
        outputs = session.run(None, {input_name: tensor})
        logits = outputs[0][0]
        probs = sigmoid(logits)

        result = {
            "status": "success",
            "gender": "Мужчина" if probs[1] > probs[0] else "Женщина",
            "age": "18-60 лет",  # fallback
            "features": [],
        }

        # Возраст
        if probs[2] > 0.5:
            result["age"] = "Младше 18"
        elif probs[4] > 0.5:
            result["age"] = "Старше 60"

        # Аксессуары и одежда (если индекс существует в предсказании модели)
        if len(probs) > 17:
            if probs[8] > 0.5:
                result["features"].append("Очки")
            if probs[9] > 0.5:
                result["features"].append("Головной убор")
            if probs[10] > 0.5:
                result["features"].append("Маска")
            if probs[11] > 0.5:
                result["features"].append("Рюкзак")

            if probs[14] > 0.5:
                result["features"].append("Длинный рукав")
            elif probs[15] > 0.5:
                result["features"].append("Короткий рукав")

            if probs[16] > 0.5:
                result["features"].append("Штаны")
            elif probs[17] > 0.5:
                result["features"].append("Юбка/Шорты")

        return result
    except Exception as e:
        logger.error(f"PP-Human inference error: {e}")
        return {"status": "error", "reason": str(e)}


def describe_person_for_bot(attr_dict: dict[str, Any]) -> str:
    """Генерирует человекочитаемую строку для Telegram-бота."""
    if attr_dict.get("status") != "success":
        return "Неизвестный человек"

    desc = f"{attr_dict.get('gender', 'Человек')} ({attr_dict.get('age', '?')})"
    features = attr_dict.get("features", [])
    if features:
        desc += f", приметы: {', '.join(features).lower()}"
    return desc
