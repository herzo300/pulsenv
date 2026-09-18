# services/ai/meme_service.py
import json
import logging
import os
import random
import urllib.parse
from datetime import UTC, datetime
from pathlib import Path
from sqlalchemy.orm import Session
from sqlalchemy import text

from PIL import Image, ImageDraw, ImageFont
from services.ai.zai_service import generate_text_using_llm
from services.data_layer.models import Report

logger = logging.getLogger(__name__)

# Directory to save locally generated/cached memes
_PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
MEME_OUTPUT_DIR = _PROJECT_ROOT / "public" / "static" / "memes"
MEME_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def sanitize_meme_text(text_val: str) -> str:
    """Sanitize and format text according to memegen.link rules."""
    if not text_val:
        return "_"
    
    # Clean text: replace spaces with underscores, handle special characters
    val = text_val.strip()
    val = val.replace(" ", "_")
    val = val.replace("?", "~q")
    val = val.replace("%", "~p")
    val = val.replace("#", "~h")
    val = val.replace("/", "~s")
    val = val.replace("\"", "''")
    val = val.replace("\n", "_")
    
    # URL encode to ensure safety
    return urllib.parse.quote(val)


def draw_fallback_meme_pillow(top_text: str, bottom_text: str, report_id: int) -> str:
    """
    Local fallback renderer using Pillow.
    Generates a dark-neon card with the meme text and saves it.
    Returns the public static path.
    """
    width, height = 600, 400
    # Create dark-gradient/neon background
    img = Image.new("RGBA", (width, height), "#020617")
    draw = ImageDraw.Draw(img)
    
    # Draw simple design borders
    draw.rectangle([10, 10, width - 10, height - 10], outline="#00E5FF", width=3)
    
    # Draw accent glow lines
    draw.line([0, 0, width, 0], fill="#00E5FF", width=5)
    draw.line([0, height, width, height], fill="#7C4DFF", width=5)

    # Text rendering details
    font_size = 24
    # Attempt to load default system fonts, fallback to default PIL font
    font = None
    font_paths = [
        "C:\\Windows\\Fonts\\arial.ttf",
        "C:\\Windows\\Fonts\\DejaVuSans.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/TTF/DejaVuSans.ttf"
    ]
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                font = ImageFont.truetype(fp, font_size)
                break
            except Exception:
                pass
    
    if not font:
        font = ImageFont.load_default()

    def draw_wrapped_text(draw_ctx, text_to_wrap, y_start, text_color):
        words = text_to_wrap.split()
        lines = []
        current_line = []
        for word in words:
            current_line.append(word)
            test_line = " ".join(current_line)
            # Simple length check for line wrapping
            if len(test_line) * 12 > width - 80:
                current_line.pop()
                lines.append(" ".join(current_line))
                current_line = [word]
        if current_line:
            lines.append(" ".join(current_line))
            
        y = y_start
        for line in lines:
            # Center text simple estimate
            txt_w = len(line) * 10
            x = (width - txt_w) // 2
            draw_ctx.text((x, y), line, font=font, fill=text_color)
            y += font_size + 8

    # Draw Top Text (Red/Accent)
    draw_wrapped_text(draw, top_text, 40, "#FF3D00")
    
    # Draw Bottom Text (Cyan/Success)
    draw_wrapped_text(draw, bottom_text, 220, "#00E5FF")
    
    # Draw logo signature
    sig = "CITY PULSE - НИЖНЕВАРТОВСК"
    draw.text(((width - len(sig) * 6) // 2, height - 35), sig, font=font, fill="#8EAFC2")

    filename = f"fallback_{report_id}_{int(datetime.now().timestamp())}.png"
    filepath = MEME_OUTPUT_DIR / filename
    img.save(filepath, "PNG")
    
    # Return path relative to mounted static directory
    return f"/map/static/memes/{filename}"


async def generate_meme_for_report(report_id: int, db: Session) -> dict:
    """
    Analyze a report and generate a city meme or warning.
    Returns a dict with caption, image_url, and templates info.
    """
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        logger.warning("Report #%s not found for meme generation", report_id)
        return {"error": "report_not_found"}

    title = report.title or "Городская проблема"
    desc = report.description or ""
    category = report.category or "Прочее"
    address = report.address or "Нижневартовск"

    city = "novosibirsk" if "новосибирск" in address.lower() or "нск" in address.lower() else "nizhnevartovsk"

    # Classify serious vs light-hearted
    serious_categories = ["ЧП", "Криминал", "ДТП", "Пожар", "Безопасность", "Здравоохранение"]
    is_serious = False
    if category in serious_categories:
        is_serious = True
    
    serious_keywords = ["погиб", "смерть", "травма", "пострадал", "взрыв", "убит", "грабеж", "насилие", "пожар", "горит", "авария", "дтп", "мчс", "ранен"]
    combined_text = (title + " " + desc).lower()
    if any(kw in combined_text for kw in serious_keywords):
        is_serious = True

    if is_serious:
        system_prompt = (
            "Ты — официальный информационный бот-помощник мобильного приложения 'Городской Пульс' (СообщиО).\n"
            "Твоя задача: составить серьезное, вежливое, уважительное и предупреждающее сообщение о происшествии (ЧП, пожар, авария, ДТП).\n"
            "Категорически запрещается использовать юмор, сарказм, шутить над городом, жителями, пострадавшими или допускать расовые, этнические или дискриминационные высказывания.\n"
            "Отвечай строго в формате JSON:\n"
            "{\n"
            "  \"template\": \"warning\",\n"
            "  \"top_text\": \"ВНИМАНИЕ: СЕРЬЕЗНОЕ ПРОИСШЕСТВИЕ\",\n"
            "  \"bottom_text\": \"короткое описание сути инцидента в официальном тоне (до 10 слов)\",\n"
            "  \"explanation\": \"рекомендация по безопасности или официальное предупреждение (1 предложение)\"\n"
            "}\n"
            "Не добавляй никаких других слов, только чистый JSON."
        )
    else:
        if city == "novosibirsk":
            system_prompt = (
                "Ты — сатирический бот-мемолог Новосибирска (Пылесибирска). Твоя задача: превратить мелкую городскую проблему ЖКХ, дорог, пробок или благоустройства в смешной мем.\n"
                "Используй местный колорит: вечные пробки на Димитровском/Коммунальном мосту, Хилокский рынок, ямы на Красном проспекте.\n"
                "ПРАВИЛА БЕЗОПАСНОСТИ: Категорически запрещается шутить над пострадавшими, шутить над городом, жителями, а также допускать любые расовые, этнические или дискриминационные шутки.\n"
                "Отвечай ТОЛЬКО в формате JSON:\n"
                "{\n"
                "  \"template\": \"drake\" | \"two-buttons\" | \"disastergirl\" | \"sad-keanu\" | \"fine\",\n"
                "  \"top_text\": \"короткий текст сверху (до 8-10 слов в саркастичном тоне про проблему)\",\n"
                "  \"bottom_text\": \"короткий текст снизу (до 8-10 слов, завершающий шутку)\",\n"
                "  \"explanation\": \"короткое забавное пояснение или саркастическая цитата (1 предложение)\"\n"
                "}\n"
                "Не добавляй никакого другого текста, кроме JSON."
            )
        else:
            system_prompt = (
                "Ты — сатирический бот-мемолог Нижневартовска. Твоя задача: превратить мелкую городскую проблему ЖКХ, дорог или благоустройства в смешной мем.\n"
                "Используй местный колорит: Самотлор, суровые морозы -40C, гигантские сугробы, коммунальщиков, вечное ожидание лета, комаров.\n"
                "ПРАВИЛА БЕЗОПАСНОСТИ: Категорически запрещается шутить над пострадавшими, шутить над городом, жителями, а также допускать любые расовые, этнические или дискриминационные шутки.\n"
                "Отвечай ТОЛЬКО в формате JSON:\n"
                "{\n"
                "  \"template\": \"drake\" | \"two-buttons\" | \"disastergirl\" | \"sad-keanu\" | \"fine\",\n"
                "  \"top_text\": \"короткий текст сверху (до 8-10 слов в саркастичном тоне про проблему)\",\n"
                "  \"bottom_text\": \"короткий текст снизу (до 8-10 слов, завершающий шутку)\",\n"
                "  \"explanation\": \"короткое забавное пояснение или саркастическая цитата (1 предложение)\"\n"
                "}\n"
                "Не добавляй никакого другого текста, кроме JSON."
            )

    user_prompt = (
        f"Создай описание для ситуации:\n"
        f"- Город: {'Новосибирск' if city == 'novosibirsk' else 'Нижневартовск'}\n"
        f"- Категория: {category}\n"
        f"- Название: {title}\n"
        f"- Описание: {desc[:600]}\n"
        f"- Адрес: {address}\n\n"
    )
    if not is_serious:
        user_prompt += (
            f"Выбери наиболее подходящий шаблон мема:\n"
            f"1. drake (для сравнения глупых действий с умными)\n"
            f"2. two-buttons (сложный выбор между двумя решениями)\n"
            f"3. disastergirl (ирония на фоне проблемы)\n"
            f"4. sad-keanu (грусть, долгое ожидание ремонта)\n"
            f"5. fine (когда всё горит/затоплено, но все делают вид, что всё нормально)\n"
        )

    # Use LLM helper to generate the JSON payload
    llm_response = await generate_text_using_llm(
        user_prompt=user_prompt,
        system_prompt=system_prompt,
        max_tokens=250,
        temperature=0.8,
        model="google/gemini-2.5-flash",
    )

    template = "warning" if is_serious else "sad-keanu"
    top_text = "ВНИМАНИЕ: СЕРЬЕЗНОЕ ПРОИСШЕСТВИЕ" if is_serious else f"Проблема на {address}"
    bottom_text = title
    explanation = "Будьте осторожны." if is_serious else "Коммунальный юмор."
    parsed = False

    if llm_response:
        try:
            # Clean possible markdown format block in JSON response
            cleaned_resp = llm_response.strip()
            if cleaned_resp.startswith("```json"):
                cleaned_resp = cleaned_resp[7:]
            if cleaned_resp.endswith("```"):
                cleaned_resp = cleaned_resp[:-3]
            cleaned_resp = cleaned_resp.strip()
            
            data = json.loads(cleaned_resp)
            if "top_text" in data and "bottom_text" in data:
                template = str(data.get("template", "warning" if is_serious else "sad-keanu")).lower()
                top_text = str(data["top_text"])
                bottom_text = str(data["bottom_text"])
                explanation = str(data.get("explanation", "Будьте осторожны." if is_serious else "Коммунальный юмор."))
                parsed = True
        except Exception as e:
            logger.warning("Failed to parse LLM response: %s. Response was: %s", e, llm_response)

    # If parsing failed and it is not serious, construct template-based heuristics
    if not parsed and not is_serious:
        templates_fallback = {
            "Дороги": ("drake", "Построить новые дороги", "Ждать пока ямы засыплет снегом"),
            "ЖКХ": ("fine", "Отопление отключили в мороз", "Всё нормально, закаляемся"),
            "Снег/Наледь": ("sad-keanu", "Весна пришла в Сибирь", "Сугробы растаяли вместе с асфальтом"),
            "Прочее": ("sad-keanu", f"Жалоба: {title}", "Ждем решения коммунальных служб")
        }
        fallback_data = templates_fallback.get(category, templates_fallback["Прочее"])
        template, top_text, bottom_text = fallback_data

    # Map templates to memegen.link keys
    memegen_map = {
        "drake": "drake",
        "two-buttons": "twobuttons",
        "disastergirl": "disastergirl",
        "sad-keanu": "sad-keanu",
        "fine": "fine",
        "warning": "fine"
    }
    api_template = memegen_map.get(template, "sad-keanu")

    # Construct the final dynamic image URL using memegen.link
    clean_top = sanitize_meme_text(top_text)
    clean_bottom = sanitize_meme_text(bottom_text)
    image_url = f"https://api.memegen.link/images/{api_template}/{clean_top}/{clean_bottom}.png"

    # Save to DB
    try:
        db.execute(
            text(
                "INSERT INTO city_memes (caption, image_url, category, meme_type, likes, created_at) "
                "VALUES (:cap, :url, :cat, :type, 0, :now)"
            ),
            {
                "cap": f"{top_text}\n{bottom_text}",
                "url": image_url,
                "cat": category,
                "type": template,
                "now": datetime.now(UTC).replace(tzinfo=None)
            }
        )
        db.commit()
    except Exception as dberr:
        logger.error("Failed to save generated meme to DB: %s", dberr)
        db.rollback()
        # Fallback to local Pillow image rendering
        fallback_url = draw_fallback_meme_pillow(top_text, bottom_text, report_id)
        image_url = fallback_url

    return {
        "caption": f"{top_text}\n{bottom_text}",
        "image_url": image_url,
        "meme_type": template,
        "category": category,
        "is_serious": is_serious,
        "explanation": explanation,
        "share_text": f"🏙️ City Pulse [Сигнал #{report_id}]\n\n{top_text}\n{bottom_text}\n\nПодробнее в приложении."
    }
