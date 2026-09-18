# services/business/image_generator.py
import httpx
import logging
import urllib.parse
import time
from services.monitoring.local_media_storage import save_image

logger = logging.getLogger(__name__)

async def generate_ai_image_for_description(description: str, category: str) -> str | None:
    """
    Generates a high-quality relevant 3D/realistic photo using Pollinations AI
    based on the complaint description and category, saves it locally, and returns the URL.
    """
    if not description:
        return None
        
    try:
        # Translate simple keywords for Russian categories to english for higher quality prompts
        cat_en = "city problem"
        cat_lower = category.lower()
        if "вода" in cat_lower or "канализация" in cat_lower or "жкг" in cat_lower:
            cat_en = "water pipe leakage, flooding street, urban utilities issue"
        elif "дорог" in cat_lower:
            cat_en = "pothole on asphalt road, damaged street pavement"
        elif "благоустрой" in cat_lower:
            cat_en = "damaged park bench, broken street tile, messy public area"
        elif "освещен" in cat_lower or "свет" in cat_lower:
            cat_en = "broken street light pole at night, dark street"
        elif "эколог" in cat_lower or "мусор" in cat_lower:
            cat_en = "overflowing garbage container, trash bags on street"
        elif "чп" in cat_lower or "пожар" in cat_lower:
            cat_en = "emergency siren flashing, road hazard warning"
        elif "животн" in cat_lower:
            cat_en = "cute lost domestic animal cat or dog in city park"
        elif "вещ" in cat_lower:
            cat_en = "lost personal item backpack or wallet on a bench"
            
        desc_clean = description.replace("\n", " ").strip()
        # Keep prompt concise
        desc_short = desc_clean[:140]
        
        prompt = f"highly detailed realistic photo of {cat_en}: {desc_short}"
        encoded_prompt = urllib.parse.quote(prompt)
        
        # Add random seed to avoid caching
        seed_val = int(time.time())
        pollinations_url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=1024&height=1024&nologo=true&seed={seed_val}"
        
        logger.info(f"Generating AI image via Pollinations: {prompt[:100]}...")
        
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(pollinations_url)
            if response.status_code == 200 and len(response.content) > 5000:
                filename = f"gen_{seed_val}.jpg"
                url = save_image(response.content, filename)
                logger.info(f"AI image generated successfully: {url}")
                return url
            else:
                logger.warning(f"Pollinations returned code {response.status_code} or small size")
    except Exception as e:
        logger.error(f"Failed to generate AI image: {e}")
        
    return None
