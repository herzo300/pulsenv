# services/business/moderation.py
import re

# Common Russian profanity roots and patterns
MAT_PATTERN = re.compile(
    r'(?i)\b(?:[уу]бл[яю]|хуй|хуе|хуи|хуя|пизд|блять|бляд|сук[аио]|говн|гавн|гондон|гандон|мудак|мудил|дроч|залуп|курв|ебат|ебан|ебуч|ебы|охуе|ахуе|проеб|выеб|уеб|съеб|похуи)\w*\b'
)

# Dangerous/Illegal keywords in Russian
ILLEGAL_KEYWORDS = [
    "героин", "кокаин", "наркоти", "купить оружие", "взрывчат", "бомб", "террори", 
    "суицид", "убить себя", "самоубий", "экстреми", "свержение власти", "пропаганда лгбт",
    "порно", "детская порно", "купить паспорт", "подделка документов", "купить права"
]

def check_moderation(text: str) -> tuple[bool, str | None]:
    """Check text for profanity (mat) and illegal topics.
    
    Returns: (is_clean, reason_if_blocked)
    """
    if not text:
        return True, None
        
    text_lower = text.lower().strip()
    
    # 1. Check for profanity (Mat)
    if MAT_PATTERN.search(text_lower):
        return False, "Обнаружена нецензурная лексика. Пожалуйста, соблюдайте правила приличия."
        
    # 2. Check for illegal / dangerous topics
    for keyword in ILLEGAL_KEYWORDS:
        if keyword in text_lower:
            return False, "Запрос заблокирован: обнаружено упоминание тем, нарушающих законодательство РФ (наркотические вещества, оружие, экстремизм, насилие)."
            
    # 3. Check for privacy and surveillance rules (152-FZ)
    # Block requests attempting to search/track humans or cars on cameras
    is_camera_query = any(k in text_lower for k in ["камер", "видео", "поток", "эфир", "трансляц", "запись"])
    if is_camera_query:
        illegal_tracking_targets = ["человек", "люд", "мужчин", "женщин", "ребенк", "ребён", "машин", "автомобил", "номер", "госномер", "следить", "отследить", "пешеход", "водитель"]
        for target in illegal_tracking_targets:
            if target in text_lower:
                # But allow dogs!
                if "собак" in text_lower or "пес" in text_lower or "пёс" in text_lower:
                    continue
                return False, "В соответствии с 152-ФЗ 'О персональных данных' отслеживание и поиск людей или автомобилей по городским камерам запрещены. Разрешен только поиск потерянных собак."
            
    return True, None
