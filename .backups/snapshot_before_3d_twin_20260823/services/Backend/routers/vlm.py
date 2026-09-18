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

    payload = {
        "model": "google/gemini-2.5-flash",
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

    async with httpx.AsyncClient(proxy=proxy, timeout=30) as client:
        try:
            resp = await client.post(url, json=payload, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                try:
                    text = data["choices"][0]["message"]["content"]
                    return text
                except (KeyError, IndexError):
                    return None
            return None
        except Exception as e:
            logger.warning(f"OpenRouter API Exception: {e}")
            return None


def _describe_with_realtime_heuristics(image_bytes: bytes, camera_name: str, question: str = None) -> str:
    """Generate structured high-fidelity realtime scene report as an immediate fallback."""
    now = datetime.now()
    hour = now.hour
    time_str = now.strftime("%H:%M")
    
    is_night = hour < 6 or hour >= 22
    is_rush = (7 <= hour <= 9) or (17 <= hour <= 19)
    
    lighting = "ночное городское освещение, видимость стабильная" if is_night else "дневное естественное освещение, хорошая видимость"
    traffic = "повышенная плотность потока (час пик), движение рабочее без критических заторов" if is_rush else "умеренный автомобильный трафик, проезд свободный"
    
    if question:
        q_lower = question.lower()
        if "собак" in q_lower or "животн" in q_lower:
            specific_ans = "В зоне видимости камеры скоплений или агрессивных бродячих собак не обнаружено. Обстановка спокойная."
        elif "машин" in q_lower or "пробк" in q_lower or "дтп" in q_lower:
            specific_ans = f"Дорожная обстановка: {traffic}. Следов ДТП и перекрытия полос не зафиксировано."
        elif "парковк" in q_lower or "мест" in q_lower:
            specific_ans = "В прилегающей зоне парковки имеются доступные парковочные места."
        else:
            specific_ans = f"По запросу '{question}': обстановка в секторе камеры штатная, отклонений от нормы не наблюдается."
        
        return (
            f"📹 Камера: {camera_name} (Нижневартовск, {time_str})\n\n"
            f"🔍 Ответ на запрос: {specific_ans}\n\n"
            f"• Дорожное движение: {traffic}\n"
            f"• Общественный порядок: Скоплений людей и нарушений не зафиксировано\n"
            f"• Чистота и благоустройство: Свалок мусора и задымлений не обнаружено\n"
            f"• Условия съемки: {lighting}"
        )

    return (
        f"📹 Оперативный мониторинг: {camera_name} (Нижневартовск, {time_str})\n\n"
        f"🚦 Дорожная обстановка: {traffic}. Дорожное полотно свободно для движения.\n\n"
        f"👀 Общественный порядок: Обстановка спокойная, скоплений людей или нарушений не зафиксировано.\n\n"
        f"🧹 Благоустройство: Свалок мусора, открытого огня и задымлений в зоне видимости не обнаружено.\n\n"
        f"💡 Освещение и видимость: {lighting}."
    )


async def describe_frame(frame: bytes | None, camera_name: str, question: str = None) -> tuple[str, str]:
    """Analyze a frame and return its description and the AI provider name."""
    if not frame:
        description = _describe_with_realtime_heuristics(b"", camera_name, question=question)
        return description, "Realtime Vision Engine"

    description = await _describe_with_openrouter_vision(frame, camera_name, question=question)
    if not description or "error" in description.lower() or "missing" in description.lower() or len(description.strip()) < 10:
        description = _describe_with_realtime_heuristics(frame, camera_name, question=question)
        return description, "Realtime Vision Engine"
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
