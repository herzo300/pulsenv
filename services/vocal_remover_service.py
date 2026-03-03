# services/vocal_remover_service.py
import os
import asyncio
import tempfile
import logging
import httpx
import base64
from pathlib import Path
from datetime import datetime

from dotenv import load_dotenv
load_dotenv()
logger = logging.getLogger(__name__)

BACKEND = "mvsep"
MVSEP_API_URL_CREATE = "https://mvsep.com/api/separation/create"
MVSEP_API_URL_GET = "https://mvsep.com/api/separation/get"
MVSEP_API_KEY = os.getenv("MVSEP_API_KEY", "")
REPLICATE_API_TOKEN = os.getenv("REPLICATE_API_TOKEN", "")
REPLICATE_MODEL = "lucataco/mvsep-mdx23-music-separation:bf74e1f66ae08af3a14b7fefbc16de01e6e7cda66bec28e23406bb8a4e6a8e24"
AUDIO_SEPARATOR_AVAILABLE = False

MODELS = {
    "mdx_free": {
        "name": "MDX-Net (Vocals/Inst)",
        "description": "Standard high quality (Free)",
        "mvsep_model_id": 3, 
        "replicate_output": "vocals",
    },
    "ensemble_free": {
        "name": "Ensemble (Stable)",
        "description": "Balanced ensemble (Free)",
        "mvsep_model_id": 27, 
        "replicate_output": "all",
    },
}

DEFAULT_MODEL = "mdx_voc_ft"
MODELS_DIR = Path(os.getenv("VOCAL_REMOVER_MODELS_DIR", tempfile.gettempdir() + "/audio_separator_models"))
OUTPUT_DIR = Path(os.getenv("VOCAL_REMOVER_OUTPUT_DIR", tempfile.gettempdir() + "/vocal_remover_output"))

usage_stats = {"total_processed": 0, "total_duration_sec": 0, "by_model": {}, "by_user": {}, "by_backend": {}, "errors": 0}

class VocalRemoverError(Exception): pass

async def check_installation():
    lines = ["Active backend: " + BACKEND]
    is_ready = False
    if REPLICATE_API_TOKEN: is_ready = True
    return is_ready, "\n".join(lines)

async def _process_with_mvsep(input_path, model_key):
    # According to https://mvsep.com/ru/full_api
    token = os.getenv("MVSEP_API_KEY", "")
    if not token:
        raise VocalRemoverError("Ошибка: MVSEP_API_KEY не задан в .env")

    model_info = MODELS.get(model_key, MODELS[DEFAULT_MODEL])
    mvsep_model_id = model_info.get("mvsep_model_id", 11) # fallback to high-quality default

    logger.info(f"Opening file for reading: {input_path}")
    with open(input_path, "rb") as f:
        audio_data = f.read()
    
    file_size = len(audio_data)
    logger.info(f"File size: {file_size} bytes")

    files = {"audiofile": (Path(input_path).name, audio_data)}
    data = {
        "api_token": token,
        "sep_type": str(mvsep_model_id),
        "output_format": "1" # 1 for MP3
    }

    async with httpx.AsyncClient(timeout=300) as client:
        # 1. Create separation job
        logger.info(f"POSTing separation request to MVSEP... (sep_type={mvsep_model_id})")
        try:
            resp = await client.post(MVSEP_API_URL_CREATE, files=files, data=data)
            logger.info(f"MVSEP Response Status: {resp.status_code}")
        except Exception as e:
            logger.error(f"HTTPX POST Error: {e}")
            raise VocalRemoverError(f"Network error while uploading to MVSEP: {e}")

        if resp.status_code != 200:
            logger.error(f"MVSEP Error Response: {resp.text}")
            raise VocalRemoverError(f"MVSEP Create Error: {resp.status_code}")
        
        result = resp.json()
        logger.debug(f"MVSEP JSON Response: {result}")
        if not result.get("success"):
            err_msg = result.get("message") or str(result.get("errors", "Unknown error"))
            raise VocalRemoverError(f"MVSEP Create Failed: {err_msg}")
        
        # Hash is often in result["data"]["hash"] or result["hash"]
        job_hash = result.get("hash")
        if not job_hash and "data" in result:
            job_hash = result["data"].get("hash")
            
        if not job_hash:
            raise VocalRemoverError("MVSEP error: No hash returned in response")

        # 2. Poll for results
        logger.info(f"Polling MVSEP job {job_hash}...")
        for _ in range(120): # max 10 mins (5s * 120)
            await asyncio.sleep(5)
            status_resp = await client.get(f"{MVSEP_API_URL_GET}?hash={job_hash}")
            if status_resp.status_code != 200:
                continue
            
            status_data = status_resp.json()
            # The structure from docs: status can be done, waiting, processing, etc.
            status = status_data.get("status")
            if status == "done":
                # Find download links
                # In docs, 'done' means files are ready. 
                # Links are often in download_urls or just extra fields
                v_url, i_url = None, None
                files_list = status_data.get("files", [])
                for f_info in files_list:
                    if "vocals" in f_info.get("name", "").lower():
                        v_url = f_info.get("url")
                    else:
                        i_url = f_info.get("url")
                
                # Fallback if links are top-level
                if not v_url: v_url = status_data.get("vocals")
                if not i_url: i_url = status_data.get("instrumental") or status_data.get("no_vocals")

                if not v_url or not i_url:
                    raise VocalRemoverError("MVSEP error: Job done but no download links found")
                
                # 3. Download results
                output_dir = OUTPUT_DIR / datetime.now().strftime("%Y%m%d_%H%M%S")
                output_dir.mkdir(parents=True, exist_ok=True)
                v_p = str(output_dir / "vocals.mp3")
                i_p = str(output_dir / "instrumental.mp3")

                async with client.stream("GET", v_url) as r:
                    with open(v_p, "wb") as f:
                        async for chunk in r.aiter_bytes(): f.write(chunk)
                async with client.stream("GET", i_url) as r:
                    with open(i_p, "wb") as f:
                        async for chunk in r.aiter_bytes(): f.write(chunk)
                
                return v_p, i_p, {"backend": "mvsep", "hash": job_hash}
            
            elif status == "failed":
                raise VocalRemoverError(f"MVSEP processing failed for job {job_hash}")
        
        raise VocalRemoverError("MVSEP error: Timeout waiting for separation")

async def _process_with_replicate(input_path, model_key):
    if not REPLICATE_API_TOKEN: raise VocalRemoverError("No token")
    with open(input_path, "rb") as f: audio_b64 = base64.b64encode(f.read()).decode()
    headers = {"Authorization": "Token " + REPLICATE_API_TOKEN, "Content-Type": "application/json"}
    payload = {"version": REPLICATE_MODEL.split(":")[1], "input": {"audio": "data:audio/mpeg;base64," + audio_b64, "output_format": "mp3"}}
    async with httpx.AsyncClient(timeout=600) as client:
        resp = await client.post("https://api.replicate.com/v1/predictions", headers=headers, json=payload)
        p_id = resp.json()["id"]
        for _ in range(120):
            await asyncio.sleep(5)
            s_resp = await client.get("https://api.replicate.com/v1/predictions/" + p_id, headers=headers)
            status = s_resp.json()
            if status["status"] == "succeeded":
                out = status["output"]
                output_dir = OUTPUT_DIR / datetime.now().strftime("%Y%m%d_%H%M%S")
                output_dir.mkdir(parents=True, exist_ok=True)
                v_p, i_p = None, None
                if "vocals" in out:
                    v_p = str(output_dir / "vocals.mp3")
                    async with client.stream("GET", out["vocals"]) as r:
                        with open(v_p, "wb") as f:
                            async for chunk in r.aiter_bytes(): f.write(chunk)
                if "no_vocals" in out:
                    i_p = str(output_dir / "instrumental.mp3")
                    async with client.stream("GET", out["no_vocals"]) as r:
                        with open(i_p, "wb") as f:
                            async for chunk in r.aiter_bytes(): f.write(chunk)
                return v_p, i_p, {"backend": "replicate"}
        raise VocalRemoverError("Timeout")

AUDIO_SEPARATOR_AVAILABLE = True

async def _process_local(i_p, m_k, o_f="mp3"):
    try:
        import torch
        import numpy
        # Check others if needed
    except ImportError as e:
        logger.error(f"Missing AI libraries: {e}")
        raise VocalRemoverError(
            "⚠️ Локальная обработка аудио недоступна.\n\n"
            "Серверу требуются AI-библиотеки (PyTorch), которые не поддерживаются текущей версией Python (3.14).\n\n"
            "Рекомендуется использовать внешнюю мини-апп ссылку из админ-панели."
        )

    # If we made it here, torch exists, but other deps might still be missing
    if not AUDIO_SEPARATOR_AVAILABLE:
        raise VocalRemoverError("⚠️ Библиотека audio-separator не настроена.")
        
    return None, None, {"error": "not_implemented"}

async def separate_audio(input_path, output_dir=None, model_key=DEFAULT_MODEL, output_format="mp3", user_id=None, backend=None):
    use_backend = backend or BACKEND
    
    if use_backend == "replicate": return await _process_with_replicate(input_path, model_key)
    
    # Check if we should use MVSEP (cloud)
    if MVSEP_API_KEY:
        try:
            return await _process_with_mvsep(input_path, model_key)
        except Exception as e:
            logger.warning(f"MVSEP failed: {e}. Falling back to local.")

    # Try local with our safety check
    return await _process_local(input_path, model_key, output_format)

def get_models_list(): return "Models available: mdx_voc_ft, mdx_inst3, demucs_htdemucs, ensemble"
def get_usage_stats(): return "Stats: OK"
async def cleanup_old_files(max_age_hours=24): return 0
