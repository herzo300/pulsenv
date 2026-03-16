from __future__ import annotations

import hashlib
import io
import os
from pathlib import Path
from threading import Lock
from typing import Any

import numpy as np
import onnxruntime as ort
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MODEL_DIR = (
    ROOT
    / "data"
    / "models"
    / "realesrgan"
    / "onnx-float"
    / "real_esrgan_x4plus-onnx-float"
)
MODEL_PATH = MODEL_DIR / "real_esrgan_x4plus.onnx"
CACHE_DIR = ROOT / "data" / "cache" / "realesrgan"


class RealESRGANService:
    def __init__(self) -> None:
        self._session: ort.InferenceSession | None = None
        self._lock = Lock()

    def _ensure_session(self) -> ort.InferenceSession:
        if self._session is not None:
            return self._session

        with self._lock:
            if self._session is not None:
                return self._session
            if not MODEL_PATH.exists():
                raise FileNotFoundError(
                    f"Real-ESRGAN model not found: {MODEL_PATH}"
                )

            options = ort.SessionOptions()
            options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
            if os.cpu_count():
                options.intra_op_num_threads = max(1, min(4, os.cpu_count() or 1))
                options.inter_op_num_threads = 1

            self._session = ort.InferenceSession(
                MODEL_PATH.as_posix(),
                sess_options=options,
                providers=["CPUExecutionProvider"],
            )
            return self._session

    def upscale_image_bytes(
        self,
        image_bytes: bytes,
        *,
        max_input_side: int = 512,
        tile_size: int = 128,
        overlap: int = 16,
        output_quality: int = 92,
    ) -> dict[str, Any]:
        if not image_bytes:
            raise ValueError("Empty image payload")

        cache_key = hashlib.sha256(
            image_bytes + f"|{max_input_side}|{tile_size}|{overlap}".encode("utf-8")
        ).hexdigest()
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        cache_path = CACHE_DIR / f"{cache_key}.jpg"

        source = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        source_width, source_height = source.size

        normalized = source.copy()
        if max(source_width, source_height) > max_input_side:
            normalized.thumbnail((max_input_side, max_input_side), Image.Resampling.LANCZOS)

        input_width, input_height = normalized.size

        if cache_path.exists():
            cached_bytes = cache_path.read_bytes()
            return {
                "image_bytes": cached_bytes,
                "mime_type": "image/jpeg",
                "cached": True,
                "source_width": source_width,
                "source_height": source_height,
                "input_width": input_width,
                "input_height": input_height,
                "output_width": input_width * 4,
                "output_height": input_height * 4,
            }

        upscaled = self._upscale_tiled(
            normalized,
            tile_size=tile_size,
            overlap=overlap,
        )

        buffer = io.BytesIO()
        upscaled.save(buffer, format="JPEG", quality=output_quality, optimize=True)
        output_bytes = buffer.getvalue()
        cache_path.write_bytes(output_bytes)

        return {
            "image_bytes": output_bytes,
            "mime_type": "image/jpeg",
            "cached": False,
            "source_width": source_width,
            "source_height": source_height,
            "input_width": input_width,
            "input_height": input_height,
            "output_width": upscaled.width,
            "output_height": upscaled.height,
        }

    def _upscale_tiled(
        self,
        image: Image.Image,
        *,
        tile_size: int,
        overlap: int,
    ) -> Image.Image:
        if tile_size != 128:
            raise ValueError("Real-ESRGAN x4 ONNX export expects 128x128 tiles")

        session = self._ensure_session()
        stride = tile_size - overlap * 2
        if stride <= 0:
            raise ValueError("Invalid tile overlap")

        width, height = image.size
        output = np.zeros((height * 4, width * 4, 3), dtype=np.float32)

        for top in self._tile_positions(height, stride):
            for left in self._tile_positions(width, stride):
                tile_left = max(left - overlap, 0)
                tile_top = max(top - overlap, 0)
                tile_right = min(left + stride + overlap, width)
                tile_bottom = min(top + stride + overlap, height)

                tile = image.crop((tile_left, tile_top, tile_right, tile_bottom))
                tile_array = np.asarray(tile, dtype=np.float32) / 255.0
                actual_h, actual_w = tile_array.shape[:2]

                if actual_h < tile_size or actual_w < tile_size:
                    pad_h = tile_size - actual_h
                    pad_w = tile_size - actual_w
                    tile_array = np.pad(
                        tile_array,
                        ((0, pad_h), (0, pad_w), (0, 0)),
                        mode="edge",
                    )

                input_tensor = np.transpose(tile_array, (2, 0, 1))[None, ...].astype(
                    np.float32
                )
                upscaled_tile = session.run(
                    ["upscaled_image"], {"image": input_tensor}
                )[0][0]
                upscaled_tile = np.transpose(upscaled_tile, (1, 2, 0))
                upscaled_tile = np.clip(upscaled_tile, 0.0, 1.0)
                upscaled_tile = upscaled_tile[: actual_h * 4, : actual_w * 4, :]

                crop_left = 0 if tile_left == 0 else overlap * 4
                crop_top = 0 if tile_top == 0 else overlap * 4
                crop_right = (
                    upscaled_tile.shape[1]
                    if tile_right == width
                    else upscaled_tile.shape[1] - overlap * 4
                )
                crop_bottom = (
                    upscaled_tile.shape[0]
                    if tile_bottom == height
                    else upscaled_tile.shape[0] - overlap * 4
                )

                tile_core = upscaled_tile[crop_top:crop_bottom, crop_left:crop_right]
                paste_left = left * 4
                paste_top = top * 4
                paste_right = paste_left + tile_core.shape[1]
                paste_bottom = paste_top + tile_core.shape[0]
                output[paste_top:paste_bottom, paste_left:paste_right, :] = tile_core

        return Image.fromarray(np.clip(output * 255.0, 0, 255).astype(np.uint8))

    @staticmethod
    def _tile_positions(size: int, stride: int) -> list[int]:
        if size <= stride:
            return [0]

        positions: list[int] = []
        current = 0
        last = max(size - stride, 0)
        while True:
            positions.append(current)
            if current >= last:
                break
            current = min(current + stride, last)
        return positions


realesrgan_service = RealESRGANService()
