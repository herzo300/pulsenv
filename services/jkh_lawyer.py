import os
import re
import logging
from io import BytesIO
from datetime import datetime
from reportlab.lib.pagesizes import A4
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors

from services.business.pdf_generator import register_cyrillic_font, rewrite_description_to_official_language
from services.ai.zai_service import generate_text_using_llm

logger = logging.getLogger(__name__)

# Локальная база знаний по ЖКХ и законам РФ (для RAG)
LAW_DATABASE = [
    {
        "source": "Постановление Правительства РФ № 354 (Приложение №1, Раздел VI)",
        "topic": "отопление",
        "keywords": ["отопление", "батарея", "холодно", "тепло", "радиатор", "замерзаем"],
        "summary": "Температура воздуха в жилых помещениях в Нижневартовске должна быть не ниже +20°C (в угловых комнатах — +22°C), так как температура на улице зимой опускается ниже -30°C.",
        "limits": "Допустимый перерыв отопления: не более 24 часов в месяц; не более 16 часов единовременно при температуре в квартире от +12°C до нормативной; не более 8 часов — при +10..+12°C; не более 4 часов — при температуре ниже +10°C.",
        "penalty": "За каждый час превышения нормы плата за отопление снижается на 0,15% от месячной стоимости услуги."
    },
    {
        "source": "Постановление Правительства РФ № 354 (Приложение №1, Раздел II)",
        "topic": "горячая вода",
        "keywords": ["горячая вода", "гвс", "кипяток", "еле теплая", "бойлер", "душ"],
        "summary": "Температура горячей воды в точке водоразбора должна быть не ниже 60°C и не выше 75°C (допустимые отклонения: ночью до 5°C, днем до 3°C).",
        "limits": "Допустимый перерыв подачи ГВС: не более 8 часов суммарно в месяц; не более 4 часов единовременно (при аварии на тупиковой магистрали — до 24 часов).",
        "penalty": "Каждые 3°C отклонения температуры воды снижают плату на 0,1% за каждый час нарушения. При температуре ниже 40°C оплата производится по тарифу холодной воды."
    },
    {
        "source": "Постановление Правительства РФ № 354 (Приложение №1, Раздел I)",
        "topic": "холодная вода",
        "keywords": ["холодная вода", "хвс", "нет воды", "водопровод"],
        "summary": "Холодная вода должна поставляться бесперебойно и соответствовать санитарным нормам СанПиН по чистоте, цвету и запаху.",
        "limits": "Допустимый перерыв подачи ХВС: не более 8 часов суммарно в месяц; не более 4 часов единовременно.",
        "penalty": "За каждый час превышения допустимого перерыва плата снижается на 0,15%."
    },
    {
        "source": "Постановление Правительства РФ № 354 (Приложение №1, Раздел IV)",
        "topic": "электроэнергия",
        "keywords": ["свет", "электричество", "электроэнергия", "напряжение", "мигает"],
        "summary": "Подача электроэнергии должна быть бесперебойной, параметры напряжения должны соответствовать ГОСТ (220 В ±10%).",
        "limits": "Допустимый перерыв: 2 часа при наличии резервного источника питания; 24 часа — при отсутствии резерва.",
        "penalty": "За каждый час превышения лимита плата за электроэнергию снижается на 0,15%."
    },
    {
        "source": "Жилищный кодекс РФ (ст. 161, 162)",
        "topic": "содержание общего имущества",
        "keywords": ["управляющая", "ук", "крыша", "подъезд", "мусор", "уборка", "двор", "стена", "подвал"],
        "summary": "Управляющая компания обязана обеспечивать благоприятные и безопасные условия проживания граждан, надлежащее содержание общего имущества в многоквартирном доме (МКД) и отвечать за его качество перед собственниками.",
        "limits": "Работы по уборке подъездов, ремонту кровли и содержанию придомовой территории должны выполняться в соответствии с минимальным перечнем услуг (Постановление Правительства № 290).",
        "penalty": "Собственники имеют право требовать соразмерного снижения платы за содержание жилого помещения при ненадлежащем качестве услуг."
    }
]

def search_housing_laws(query: str) -> dict | None:
    """
    Выполняет поиск по базе знаний ЖКХ на основе пересечения ключевых слов (RAG-сегмент).
    """
    clean_query = re.sub(r'\W+', ' ', query.lower())
    words = set(clean_query.split())
    
    best_match = None
    max_score = 0
    
    for doc in LAW_DATABASE:
        score = sum(1 for kw in doc["keywords"] if kw in clean_query)
        if score > max_score:
            max_score = score
            best_match = doc
            
    return best_match

async def answer_legal_query(query: str) -> str:
    """
    Анализирует запрос пользователя через Гермеса, ищет нормы в базе знаний и генерирует юридический ответ.
    """
    doc = search_housing_laws(query)
    
    if not doc:
        # Если совпадений нет, даем общий юридический ответ на основе знаний LLM
        system_prompt = (
            "Ты — квалифицированный юрист по жилищному праву (ЖКХ) РФ. Ответь пользователю на его вопрос вежливо, "
            "ссылаясь на Жилищный кодекс или Постановление Правительства РФ № 354, если применимо. "
            "В конце ответа спроси, хочет ли он составить официальную претензию в УК."
        )
        try:
            res = await generate_text_using_llm(user_prompt=query, system_prompt=system_prompt, max_tokens=500, temperature=0.3)
            if res:
                return res
        except Exception:
            pass
        return (
            "Здравствуйте! По закону управляющая компания обязана предоставлять коммунальные услуги надлежащего качества. "
            "Если у вас есть перебои, вы имеете право составить претензию. Хотите, я помогу вам составить бланк претензии в УК?"
        )
    
    # Формируем промпт на основе найденных законов
    system_prompt = (
        "Ты — высококвалифицированный AI-юрист Гермес по вопросам ЖКХ в Нижневартовске.\n"
        "Ответь пользователю на его жалобу, используя следующие официальные нормы:\n"
        f"Источник: {doc['source']}\n"
        f"Нормативы: {doc['summary']}\n"
        f"Лимиты перерывов: {doc['limits']}\n"
        f"Штрафы/Снижение платы: {doc['penalty']}\n\n"
        "Инструкции:\n"
        "- Объясни его права простыми словами, ссылаясь на указанный закон.\n"
        "- Напиши, сколько градусов должно быть или сколько времени допускается перерыв.\n"
        "- Укажи, что он имеет право на снижение платы.\n"
        "- В САМОМ КОНЦЕ ответа обязательно добавь фразу строго в таком формате:\n"
        "«Хотите составить официальную претензию в управляющую компанию? Я могу сгенерировать готовый PDF-документ.»"
    )
    
    try:
        ans = await generate_text_using_llm(
            user_prompt=query,
            system_prompt=system_prompt,
            max_tokens=600,
            temperature=0.3
        )
        if ans:
            return ans
    except Exception as e:
        logger.error("Failed to generate legal answer: %s", e)
        
    return (
        f"Согласно {doc['source']}, {doc['summary']} {doc['limits']} "
        f"Вы имеете право на снижение платы. Хотите составить официальную претензию в управляющую компанию? Я могу сгенерировать готовый PDF-документ."
    )

def generate_jkh_claim_pdf(user_name: str, address: str, uk_name: str, phone: str, complaint_text: str) -> BytesIO:
    """
    Генерирует юридически грамотный PDF-документ претензии в УК.
    """
    buffer = BytesIO()
    font_name = register_cyrillic_font()
    
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=40,
        leftMargin=50,
        topMargin=40,
        bottomMargin=40
    )
    
    # Переводим описание проблемы на деловой стиль
    # (поскольку функция асинхронная, запускаем ее в блокирующем стиле через run_in_threadpool или run_async_sync)
    from services.business.pdf_generator import run_async_sync
    official_desc = run_async_sync(rewrite_description_to_official_language(complaint_text, "ЖКХ"))
    
    styles = getSampleStyleSheet()
    
    # Стили с поддержкой кириллицы
    style_normal = ParagraphStyle(
        name='NormalCyr',
        fontName=font_name,
        fontSize=10,
        leading=14,
        textColor=colors.HexColor('#222222')
    )
    
    style_header = ParagraphStyle(
        name='HeaderCyr',
        fontName=font_name,
        fontSize=10,
        leading=13,
        alignment=2, # Right alignment
        textColor=colors.HexColor('#333333')
    )
    
    style_title = ParagraphStyle(
        name='TitleCyr',
        fontName=font_name,
        fontSize=14,
        leading=18,
        alignment=1, # Center alignment
        spaceAfter=15,
        textColor=colors.HexColor('#111111')
    )
    
    story = []
    
    # 1. Шапка (справа)
    header_text = (
        f"<b>Кому:</b> Руководителю УК «{uk_name}»<br/>"
        f"<b>Адрес УК:</b> г. Нижневартовск, ХМАО-Югра<br/>"
        f"<b>От кого:</b> {user_name}<br/>"
        f"<b>Адрес проживания:</b> {address}<br/>"
        f"<b>Телефон:</b> {phone}<br/>"
    )
    story.append(Paragraph(header_text, style_header))
    story.append(Spacer(1, 20))
    
    # 2. Заголовок
    story.append(Paragraph("<b>ПРЕТЕНЗИЯ (ЗАЯВЛЕНИЕ)</b><br/>о нарушении нормативов предоставления коммунальных услуг", style_title))
    story.append(Spacer(1, 10))
    
    # 3. Тело претензии
    body_intro = (
        f"Я, {user_name}, являюсь собственником (нанимателем) жилого помещения по адресу: {address}. "
        f"Управление нашим многоквартирным домом осуществляет управляющая компания УК «{uk_name}».<br/><br/>"
        f"Настоящим заявляю, что коммунальные услуги предоставляются исполнителем с грубыми нарушениями установленных "
        f"норм качества. А именно:<br/>"
    )
    story.append(Paragraph(body_intro, style_normal))
    story.append(Spacer(1, 8))
    
    # Текст проблемы в деловом стиле
    story.append(Paragraph(f"<i>{official_desc}</i>", style_normal))
    story.append(Spacer(1, 12))
    
    # Юридическое обоснование
    legal_base = (
        "В соответствии со статьей 161 Жилищного кодекса РФ управляющая организация обязана обеспечивать надлежащее "
        "содержание общего имущества и предоставлять коммунальные услуги надлежащего качества.<br/><br/>"
        "Согласно разделу VI Правил предоставления коммунальных услуг (утв. Постановлением Правительства РФ № 354), "
        "исполнитель обязан вести бесперебойное предоставление коммунальных услуг, соответствующих нормативным требованиям. "
        "За каждый час нарушения параметров качества размер платы за коммунальную услугу подлежит снижению на 0,15%."
    )
    story.append(Paragraph(legal_base, style_normal))
    story.append(Spacer(1, 15))
    
    # Требования
    demands = (
        "<b>На основании изложенного, ПРОШУ:</b><br/>"
        "1. Произвести замер параметров качества коммунальной услуги по указанному адресу в моем присутствии.<br/>"
        "2. Незамедлительно устранить причины нарушения качества предоставления коммунальных услуг.<br/>"
        "3. Произвести перерасчет размера платы за коммунальные услуги ненадлежащего качества в соответствии с Постановлением Правительства РФ № 354.<br/>"
        "4. Предоставить письменный ответ о принятых мерах в установленный законом срок."
    )
    story.append(Paragraph(demands, style_normal))
    story.append(Spacer(1, 30))
    
    # Подпись и дата
    date_str = datetime.now().strftime("%d.%m.%Y")
    sign_text = (
        f"Дата: _________________ {date_str} г.&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
        f"Подпись: _________________ / {user_name} /"
    )
    story.append(Paragraph(sign_text, style_normal))
    
    doc.build(story)
    buffer.seek(0)
    return buffer
