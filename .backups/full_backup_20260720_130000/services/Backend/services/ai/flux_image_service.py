# services/Backend/services/ai/flux_image_service.py — AI Image Generation via OpenRouter (Flux-1-Schnell)
import os
import logging
import httpx
import time

logger = logging.getLogger(__name__)

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
OPENROUTER_IMAGE_MODEL = "black-forest-labs/flux-1-schnell"

async def generate_signal_image_flux(title: str, category: str, description: str = "") -> str | None:
    """
    Generate an individual 3D municipal illustration for incoming signals without a photo
    using black-forest-labs/flux-1-schnell model.
    """
    prompt = (
        f"3D isometric digital art, municipal city issue in Nizhnevartovsk: {category}, "
        f"{title}. {description[:100]}. Modern urban design, vibrant lighting, realistic rendering."
    )

    # 1. Primary: OpenRouter FLUX.1 Schnell API if key is present
    api_key = os.getenv("OPENROUTER_API_KEY") or os.getenv("openrouter_api_key", "")
    if api_key:
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(
                    "https://openrouter.ai/api/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {api_key}",
                        "Content-Type": "application/json",
                        "HTTP-Referer": "https://citypulse.nizhnevartovsk.ru",
                        "X-Title": "City Pulse Nizhnevartovsk",
                    },
                    json={
                        "model": OPENROUTER_IMAGE_MODEL,
                        "messages": [
                            {"role": "user", "content": f"Generate image: {prompt}"}
                        ]
                    }
                )
                if resp.status_code == 200:
                    data = resp.json()
                    choices = data.get("choices", [])
                    if choices:
                        content = choices[0].get("message", {}).get("content", "")
                        if "http" in content:
                            # Extract generated image URL
                            import re
                            urls = re.findall(r'https?://[^\s<">]+', content)
                            if urls:
                                return urls[0]
        except Exception as e:
            logger.warning(f"Failed to generate image via OpenRouter FLUX: {e}")

    # 2. Fallback: Fast Pollinations FLUX.1 Schnell endpoint (0 RUB / free)
    try:
        import urllib.parse
        encoded_prompt = urllib.parse.quote(prompt)
        seed = int(time.time())
        pollinations_url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=800&height=600&seed={seed}&model=flux"
        return pollinations_url
    except Exception as err:
        logger.error(f"Fallback pollinations image generation failed: {err}")
        return None
