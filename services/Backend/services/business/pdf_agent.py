import logging
try:
    from services.Backend.services.ai.zai_service import generate_text_using_llm
except ImportError:
    from services.ai.zai_service import generate_text_using_llm

logger = logging.getLogger(__name__)

async def draft_official_complaint_text(raw_text: str, category: str) -> str:
    """
    Uses the AI agent to rewrite a raw user complaint into an official, formal 
    request text suitable for a PDF document.
    """
    system_prompt = (
        "You are an expert legal assistant in Russia. Your task is to rewrite a raw complaint from a citizen "
        "into a formal, polite, and legally sound request to the authorities (FZ-59 style). "
        "Remove any emotional language or profanity. Keep it concise, professional, and clear. "
        "Only output the rewritten text. Do not add any introductory or concluding remarks like 'Here is the text'. "
        "The language must be Russian."
    )
    
    user_prompt = f"Категория проблемы: {category}\n\nТекст жалобы:\n{raw_text}"
    
    try:
        draft = await generate_text_using_llm(
            user_prompt=user_prompt,
            system_prompt=system_prompt,
            max_tokens=500,
            temperature=0.3
        )
        if draft:
            return draft.strip()
    except Exception as e:
        logger.error(f"Failed to draft official complaint text: {e}")
    
    # Fallback to the raw text if generation fails
    return raw_text
