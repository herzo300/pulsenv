import asyncio
import logging
import os
import shutil
import subprocess
import tempfile
from datetime import datetime

import httpx
from fastapi import APIRouter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/vlm", tags=["vision-language"])

VLM_ENABLED = os.getenv("VLM_ENABLED", "true").lower() in ("1", "true", "yes")


def _capture_frame_from_url(camera_url: str, timeout: int = 10) -> bytes | None:
    """Capture a single frame from HLS/HTTP stream using ffmpeg."""
    from services.business.camera_stream_utils import (
        resolve_camera_stream_url,
        upstream_headers_for_url,
    )

    target = resolve_camera_stream_url(camera_url)
    if not target:
        target = camera_url.strip()

    ffmpeg_path = shutil.which("ffmpeg")
    if not ffmpeg_path:
        # Fallback to local project bin folder
        project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
        local_ffmpeg = os.path.join(project_root, "tools", "bin", "ffmpeg.exe")
        if os.path.exists(local_ffmpeg):
            ffmpeg_path = local_ffmpeg

    if not ffmpeg_path:
        logger.warning("ffmpeg not found, cannot capture frame")
        return None

    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmpfile:
        tmp_path = tmpfile.name

    headers = upstream_headers_for_url(target)
    header_args: list[str] = []
    if headers.get("Referer"):
        header_args.extend(["-headers", f"Referer: {headers['Referer']}\r\n"])

    # Opt args to prevent hangs: adjust based on RTSP vs HTTP/HTTPS
    opt_args = []
    if target.startswith("rtsp://"):
        opt_args.extend([
            "-rtsp_transport", "tcp",
            "-timeout", str(timeout * 1_000_000),
        ])
    else:
        opt_args.extend([
            "-timeout", str(timeout * 1_000_000),
            "-analyzeduration", "1500000",
            "-probesize", "1000000",
        ])

    try:
        cmd = [
            ffmpeg_path,
            *header_args,
            *opt_args,
            "-y",
            "-i",
            target,
            "-vframes",
            "1",
            "-q:v",
            "2",
            "-frames:v",
            "1",
            tmp_path,
        ]
        result = subprocess.run(
            cmd,
            capture_output=True,
            timeout=timeout + 5,
        )
        if result.returncode == 0 and os.path.exists(tmp_path):
            with open(tmp_path, "rb") as f:
                return f.read()
        else:
            logger.debug(
                "ffmpeg failed: %s",
                result.stderr.decode("utf-8", errors="replace")[:200],
            )
            return None
    except Exception as e:
        logger.warning("Frame capture error: %s", e)
        return None
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


async def _describe_with_openrouter_vision(image_bytes: bytes, camera_name: str, question: str = None) -> str:
    """Describe camera frame using OpenRouter Vision API."""
    import base64
    img_b64 = base64.b64encode(image_bytes).decode("utf-8")
    
    api_key = (
        os.getenv("OPENROUTER_API_KEY")
        or os.getenv("openrouter_api_key")
        or os.getenv("GEMINI_API_KEY")
        or os.getenv("GOOGLE_API_KEY")
    )
    if api_key:
        api_key = api_key.strip()
        
    if not api_key:
        return "OpenRouter API key missing (Please set OPENROUTER_API_KEY)"

    analysis_guidelines = (
        "\nПри анализе изображения обязательно фиксируй:"
        "1. Животных (собак, кошек, потерянных домашних животных)."
        "2. Транспортные средства (наличие машин, пробки, заторы, ДТП)."
        "3. Городские проблемы (задымление, пар, открытый огонь, скопление мусора, неубранный снег/лед)."
        "4. Общую обстановку (светло/темно, осадки, видимость)."
        "\nБудь объективным и кратким. Не пытайся идентифицировать конкретных людей по лицам."
    )

    system_instruction = (
        f"Ты — оператор системы мониторинга 'City Pulse' (Нижневартовск). "
        f"Ответь на вопрос жителя по камере '{camera_name}': '{question}'. "
        f"Ответь кратко, четко на русском языке. {analysis_guidelines}"
        if question
        else (
            f"Ты — оператор системы мониторинга 'City Pulse' (Нижневартовск). "
            f"Кратко опиши текущую ситуацию на камере '{camera_name}' (обращай внимание на животных, машины, заторы, задымление, мусор). {analysis_guidelines}"
        )
    )

    # Быстрая дешёвая vision-модель (запрос пользователя: анализ камер долго
    # думал). Qwen3-VL-8B — самый дешёвый и быстрый VL на OpenRouter
    # ($0.12/M in), фолбэк: qwen3-vl-32b → gemini-2.5-flash.
    fast_vision_models = [
        "qwen/qwen3-vl-8b-instruct",
        "qwen/qwen3-vl-32b-instruct",
        "google/gemini-2.5-flash",
    ]
    payload_base = {
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": system_instruction
                    },
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{img_b64}"
                        }
                    }
                ]
            }
        ],
        "temperature": 0.1,
    }

    url = "https://openrouter.ai/api/v1/chat/completions"
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/Antigravity-City/pulsenv_project",
    }
    
    proxy = (
        os.getenv("TELEGRAM_PROXY")
        or os.getenv("HTTPS_PROXY")
        or os.getenv("ALL_PROXY")
        or ""
    ).strip()
    if not proxy:
        proxy = None

    async with httpx.AsyncClient(proxy=proxy, timeout=45) as client:
        for model in fast_vision_models:
            payload = {**payload_base, "model": model}
            try:
                resp = await client.post(url, json=payload, headers=headers)
                if resp.status_code == 200:
                    data = resp.json()
                    try:
                        text = data["choices"][0]["message"]["content"]
                        if text:
                            return text
                    except (KeyError, IndexError):
                        continue
            except Exception as e:
                logger.warning(f"Vision model {model} exception: {e}")
        return None


def _describe_with_realtime_heuristics(image_bytes: bytes, camera_name: str, question: str = None) -> str:
    """Честное сообщение о недоступности анализа (без выдуманных наблюдений по часам)."""
    now = datetime.now()
    time_str = now.strftime("%H:%M")
    if question:
        return (
            f"📹 Камера: {camera_name} ({time_str})\n\n"
            f"⚠️ ИИ-анализ кадра временно недоступен — ответить на вопрос «{question}» по изображению сейчас нельзя.\n"
            f"Попробуйте ещё раз через минуту."
        )
    return (
        f"📹 Камера: {camera_name} (Нижневартовск, {time_str})\n\n"
        f"⚠️ ИИ-анализ кадра временно недоступен.\n"
        f"Кадр получен, но модель компьютерного зрения не ответила — попробуйте повторить анализ через минуту."
    )


async def describe_frame(frame: bytes | None, camera_name: str, question: str = None) -> tuple[str, str]:
    """Analyze a frame and return its description and the AI provider name."""
    if not frame:
        description = _describe_with_realtime_heuristics(None, camera_name, question=question)
        return description, "analysis_unavailable"

    description = await _describe_with_openrouter_vision(frame, camera_name, question=question)
    if not description or "error" in description.lower() or "missing" in description.lower() or len(description.strip()) < 10:
        description = _describe_with_realtime_heuristics(frame, camera_name, question=question)
        return description, "analysis_unavailable"
    return description, "OpenRouter Vision"

from pydantic import BaseModel

class DogSearchRequest(BaseModel):
    camera_url: str
    camera_name: str

@router.post("/search-dog")
async def search_dog_on_camera(req: DogSearchRequest):
    """Ищет собаку на кадре с указанной камеры."""
    frame = _capture_frame_from_url(req.camera_url)
    if not frame:
        return {"status": "error", "message": "Не удалось получить кадр с камеры"}

    question = "Внимательно посмотри на кадр. Есть ли на нем собака (или стая собак)? Ответь только JSON: {\"found\": true/false, \"details\": \"где именно\"}"
    desc = await _describe_with_openrouter_vision(frame, req.camera_name, question=question)
    
    import json
    try:
        start = desc.find("{")
        end = desc.rfind("}") + 1
        if start != -1 and end != 0:
            parsed = json.loads(desc[start:end])
            return {"status": "success", "result": parsed}
        return {"status": "success", "result": {"found": "собака" in desc.lower(), "details": desc}}
    except Exception:
        return {"status": "success", "result": {"found": False, "details": desc}}


class RedesignFrameRequest(BaseModel):
    camera_url: str
    camera_name: str
    prompt: str = "3D детская площадка в стиле Pixar"
    is_vip: bool = False

@router.post("/redesign-frame")
async def redesign_camera_frame(req: RedesignFrameRequest):
    """Generates real-time 3D civic redesign on top of live camera stream frame."""
    full_prompt = f"photorealistic 3d architectural visualization of {req.prompt} added into urban city yard, matching camera perspective, octane 3d render, daytime lighting, 8k resolution, highly detailed"
    import time, urllib.parse
    image_url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(full_prompt)}?width=1024&height=768&seed={int(time.time()*1000)}&model=flux"
    
    return {
        "status": "success",
        "redesign_url": image_url,
        "prompt": req.prompt,
        "camera_name": req.camera_name,
    }


class SignalImageRequest(BaseModel):
    prompt: str = "Инцидент на улице Ленина"
    category: str = "Благоустройство"

@router.post("/generate-signal-image")
async def generate_signal_image(req: SignalImageRequest):
    """Generates AI visualization image for city signal or report."""
    full_prompt = f"photorealistic 3d visualization of city issue {req.prompt}, category {req.category}, urban environment, high quality render, 8k"
    import time, urllib.parse
    image_url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(full_prompt)}?width=1024&height=768&seed={int(time.time()*1000)}&model=flux"
    return {
        "status": "success",
        "image_url": image_url,
        "prompt": req.prompt,
        "category": req.category,
    }


class CityProblemAnalyzeRequest(BaseModel):
    image_base64: str
    hint: str = ""


@router.post("/analyze-city-problem")
async def analyze_city_problem(req: CityProblemAnalyzeRequest):
    """Реальная детекция городских проблем по фото с устройства (AR-камера).

    Возвращает структурированный JSON: найденные проблемы, категорию жалобы,
    уверенность и рекомендуемое действие.
    """
    import base64 as _b64
    import json as _json

    try:
        image_bytes = _b64.b64decode(req.image_base64)
    except Exception:
        return {"status": "error", "message": "Некорректный base64"}

    if len(image_bytes) < 1024:
        return {"status": "error", "message": "Пустое или слишком маленькое изображение"}

    question = (
        "Проанализируй снимок городской среды (Нижневартовск). Найди городские проблемы: "
        "ямы/разрушенное покрытие, мусор/свалка, сломанное освещение, незаконная парковка, "
        "затопление, наледь, поврежденная инфраструктура, бродячие животные. "
        "Ответь ТОЛЬКО валидным JSON без markdown: "
        '{"found": true/false, "issues": [{"type": "тип проблемы", "label": "краткое название", '
        '"confidence": 0.0-1.0, "severity": "low|medium|high"}], '
        '"category": "категория жалобы из: Дороги|ЖКХ|Благоустройство|Экология|Безопасность|Животные|Прочее", '
        '"description": "1-2 предложения что видно на снимке"}'
    )
    if req.hint:
        question += f" Контекст от пользователя: {req.hint}"

    desc = await _describe_with_openrouter_vision(image_bytes, "AR-камера жителя", question=question)
    if not desc or len(desc.strip()) < 10:
        return {"status": "error", "message": "ИИ-анализ временно недоступен, попробуйте позже"}

    try:
        start = desc.find("{")
        end = desc.rfind("}") + 1
        parsed = _json.loads(desc[start:end])
        return {"status": "success", "result": parsed}
    except Exception:
        return {
            "status": "success",
            "result": {
                "found": False,
                "issues": [],
                "category": "Прочее",
                "description": desc[:300],
            },
        }


class FoodAnalyzeRequest(BaseModel):
    image_base64: str


@router.post("/analyze-food")
async def analyze_food(req: FoodAnalyzeRequest):
    """Определение калорийности и КБЖУ продуктов на фото с авто-оценкой веса.

    VLM оценивает вес каждой порции по визуальным референсам масштаба
    (тарелка ~26 см, столовая ложка, кружка), затем считает калории
    из собственных знаний о составе продуктов.
    """
    import base64 as _b64
    import json as _json

    try:
        image_bytes = _b64.b64decode(req.image_base64)
    except Exception:
        return {"status": "error", "message": "Некорректный base64"}

    if len(image_bytes) < 1024:
        return {"status": "error", "message": "Пустое или слишком маленькое изображение"}

    question = (
        "Ты — нутрициолог. На фото еда/продукты. Определи каждый продукт и ОЦЕНИ его вес в граммах "
        "по визуальным референсам масштаба (диаметр обычной тарелки ~26 см, глубина суповой тарелки ~5 см, "
        "столовая ложка ~18 мл, кружка 250 мл). По оценённому весу рассчитай калории и БЖУ. "
        "Ответь ТОЛЬКО валидным JSON без markdown: "
        '{"items": [{"name": "название продукта", "estimated_grams": 123, "kcal_total": 456, '
        '"protein_g": 1.2, "fat_g": 3.4, "carbs_g": 5.6, "basis": "как оценил вес"}], '
        '"total": {"kcal": 0, "protein_g": 0, "fat_g": 0, "carbs_g": 0}, '
        '"weight_estimation_confidence": "low|medium|high", '
        '"advice": "краткий совет по рациону"}'
    )

    desc = await _describe_with_openrouter_vision(image_bytes, "Анализ питания", question=question)
    if not desc or len(desc.strip()) < 10:
        return {"status": "error", "message": "ИИ-анализ временно недоступен, попробуйте позже"}

    try:
        start = desc.find("{")
        end = desc.rfind("}") + 1
        parsed = _json.loads(desc[start:end])
        # Пересчитываем итоги на стороне сервера, чтобы не доверять арифметике модели
        items = parsed.get("items") or []
        total_kcal = sum(float(i.get("kcal_total") or 0) for i in items)
        total_p = sum(float(i.get("protein_g") or 0) for i in items)
        total_f = sum(float(i.get("fat_g") or 0) for i in items)
        total_c = sum(float(i.get("carbs_g") or 0) for i in items)
        parsed["total"] = {
            "kcal": round(total_kcal, 1),
            "protein_g": round(total_p, 1),
            "fat_g": round(total_f, 1),
            "carbs_g": round(total_c, 1),
        }
        return {"status": "success", "result": parsed}
    except Exception:
        return {"status": "error", "message": "Не удалось разобрать ответ модели, попробуйте ещё раз"}
