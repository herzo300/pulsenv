# services/Backend/services/ai/flux_image_service.py — AI Image & Visual Prompt Generation via Kimi K3 (TokenRouter) / DeepSeek (OpenRouter) / FLUX Realism
import os
import logging
import httpx
import time
import re
import urllib.parse
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

# Provider configuration
TOKENROUTER_URL = os.getenv("TOKENROUTER", "https://api.tokenrouter.com/v1").rstrip("/")
TOKENROUTER_API = os.getenv("TOKENROUTER_API", "sk-wsjrj1L8KPvOnbfpfZRkvIPzmDuXYiOWrpDCjnuI3qzFccn1")
TOKENROUTER_MODEL = os.getenv("TOKENROUTER_MODEL", "moonshotai/kimi-k3-free")

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "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")
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "deepseek/deepseek-v4-flash")
OPENROUTER_IMAGE_MODEL = "black-forest-labs/flux-1-schnell"

# Cost tracking: Token / Request cost estimates in RUB
COST_PER_VLM_PROMPT_RUB = 0.00015
COST_PER_IMAGE_GEN_RUB = 0.00

async def enrich_signal_visual_prompt(title: str, category: str, description: str = "") -> str:
    """
    Use Kimi K3 (via TokenRouter) or DeepSeek (via OpenRouter) to construct an ultra-high-quality,
    authentic documentary photo prompt for city signals.
    """
    system_prompt = (
        "You are an award-winning photojournalist and documentary urban photographer specializing in Siberian municipal reports (Nizhnevartovsk, Khanty-Mansiysk Autonomous Okrug). "
        "Generate a detailed, ultra-photorealistic English image prompt for a real documentary DSLR camera photograph "
        "(Sony Alpha a7R V, 35mm f/2.8 lens, natural lighting, authentic Russian residential buildings, realistic roads/puddles/snow/lighting, depicting the specific municipal incident accurately). "
        "No cartoon style, no 3D CGI look, strictly authentic documentary DSLR photo. Output ONLY the visual prompt sentence, no preamble."
    )
    user_prompt = f"Category: {category}. Title: {title}. Details: {description[:250]}."

    # 1. Try Kimi K3 via TokenRouter
    if TOKENROUTER_API:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(
                    f"{TOKENROUTER_URL}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {TOKENROUTER_API}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": TOKENROUTER_MODEL,
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": f"Generate a photographic DSLR prompt for: {user_prompt}"}
                        ],
                        "max_tokens": 140,
                        "temperature": 0.3,
                    }
                )
                if resp.status_code == 200:
                    data = resp.json()
                    content = data.get("choices", [{}])[0].get("message", {}).get("content", "").strip()
                    if content:
                        logger.info("Kimi K3 (TokenRouter) enriched prompt successfully: %s", content[:60])
                        return content
        except Exception as e:
            logger.debug("TokenRouter Kimi K3 prompt enrichment failed: %s", e)

    # 2. Try DeepSeek via OpenRouter
    if OPENROUTER_API_KEY:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(
                    "https://openrouter.ai/api/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                        "Content-Type": "application/json",
                        "HTTP-Referer": "https://citypulse.nizhnevartovsk.ru",
                        "X-Title": "City Pulse Nizhnevartovsk",
                    },
                    json={
                        "model": OPENROUTER_MODEL,
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": f"Generate a photographic DSLR prompt for: {user_prompt}"}
                        ],
                        "max_tokens": 140,
                        "temperature": 0.3,
                    }
                )
                if resp.status_code == 200:
                    data = resp.json()
                    content = data.get("choices", [{}])[0].get("message", {}).get("content", "").strip()
                    if content:
                        logger.info("DeepSeek (OpenRouter) enriched prompt successfully: %s", content[:60])
                        return content
        except Exception as e:
            logger.debug("OpenRouter DeepSeek prompt enrichment failed: %s", e)

    # Fallback template with rich photographic detail
    return f"Authentic documentary municipal photograph in Nizhnevartovsk, Western Siberia: {category}, {title}. {description[:120]}. Concrete panel residential district, real asphalt and pavement, overcast natural daylight, shot on Sony Alpha a7R IV 35mm f/2.8 lens, 8k resolution, crisp detail, realistic urban photography."


async def generate_signal_image_flux(title: str, category: str, description: str = "") -> Optional[str]:
    """
    Generate an authentic high-quality municipal photograph for incoming signals
    using Kimi K3 / DeepSeek for prompt crafting + FLUX Realism for photorealistic rendering.
    """
    # 1. Enrich prompt using Kimi K3 / DeepSeek
    prompt = await enrich_signal_visual_prompt(title, category, description)

    # 2. High-speed Pollinations FLUX Realism endpoint (1024x768, nologo, high-fidelity)
    try:
        encoded_prompt = urllib.parse.quote(prompt)
        seed = int(time.time() * 1000) % 1000000
        pollinations_url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=1024&height=768&seed={seed}&nologo=true&model=flux-realism"
        return pollinations_url
    except Exception as err:
        logger.error("Pollinations image generation failed: %s", err)
        return None
