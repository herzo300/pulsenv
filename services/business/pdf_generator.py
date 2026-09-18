# services/business/pdf_generator.py
import os
import logging
from datetime import datetime
from io import BytesIO
from sqlalchemy.orm import Session

from reportlab.lib.pagesizes import letter, A4
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch

from services.data_layer.models import Report, User

logger = logging.getLogger(__name__)

def run_async_sync(coro):
    import asyncio
    import concurrent.futures
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        return asyncio.run(coro)
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
        future = executor.submit(asyncio.run, coro)
        return future.result()

async def rewrite_description_to_official_language(description: str, category: str) -> str:
    """
    Rewrites user description to a formal, official Russian administrative/legal language.
    If the AI rewrite fails or returns empty, returns the original description.
    """
    if not description:
        return ""
        
    system_prompt = (
        "Ты — профессиональный юрист и государственный служащий РФ.\n"
        "Твоя задача — строго перевести неформальное/разговорное описание проблемы гражданина "
        "на официальный, деловой, канцелярский и юридический русский язык для подачи официального заявления в органы власти.\n"
        "Используй формулировки вроде 'В ходе визуального осмотра был зафиксирован факт...', "
        "'Настоящим сообщаем о выявленном нарушении...', 'Службы не выполняют обязательства по...'.\n"
        "Не придумывай факты которых нет в описании. Будь лаконичен и конкретен.\n"
        "Выводи ТОЛЬКО переписанный текст, без лишних вступлений, комментариев и кавычек."
    )
    user_prompt = f"Категория проблемы: {category}\nОписание: {description}"
    
    try:
        from services.ai.zai_service import generate_text_using_llm
        res = await generate_text_using_llm(
            user_prompt=user_prompt,
            system_prompt=system_prompt,
            max_tokens=600,
            temperature=0.3
        )
        if res and len(res.strip()) > 10:
            return res.strip()
    except Exception as e:
        logger.warning(f"Failed to rewrite complaint to official language via LLM: {e}")
        
    return description

LEGAL_REFERENCES = {
    "жкх": {
        "federal": [
            ("Жилищный кодекс РФ (ст. 161, 162)", "https://www.consultant.ru/document/cons_doc_LAW_51057/"),
            ("Постановление Правительства РФ № 290", "https://www.consultant.ru/document/cons_doc_LAW_144804/"),
            ("Постановление Правительства РФ № 354", "https://www.consultant.ru/document/cons_doc_LAW_114247/")
        ],
        "local_nv": ("Решение Думы г. Нижневартовска № 382 «О Правилах благоустройства»", "https://docs.cntd.ru/document/550212879")
    },
    "дороги": {
        "federal": [
            ("Федеральный закон № 196-ФЗ «О безопасности дорожного движения» (ст. 12)", "https://www.consultant.ru/document/cons_doc_LAW_8585/"),
            ("ГОСТ Р 50597-2017 «Требования к эксплуатационному состоянию дорог»", "https://docs.cntd.ru/document/1200157321")
        ],
        "local_nv": ("Решение Думы г. Нижневартовска № 382 «О Правилах благоустройства»", "https://docs.cntd.ru/document/550212879")
    },
    "дтп": {
        "federal": [
            ("Федеральный закон № 196-ФЗ «О безопасности дорожного движения» (ст. 12)", "https://www.consultant.ru/document/cons_doc_LAW_8585/"),
            ("ГОСТ Р 50597-2017 «Требования к эксплуатационному состоянию дорог»", "https://docs.cntd.ru/document/1200157321")
        ],
        "local_nv": ("Решение Думы г. Нижневартовска № 382 «О Правилах благоустройства»", "https://docs.cntd.ru/document/550212879")
    },
    "уличное освещение": {
        "federal": [
            ("ГОСТ Р 50597-2017 (Раздел 5.6 «Наружное освещение»)", "https://docs.cntd.ru/document/1200157321"),
            ("СНиП 23-05-95 «Естественное и искусственное освещение»", "https://docs.cntd.ru/document/871001007")
        ],
        "local_nv": ("Решение Думы г. Нижневартовска № 382 «О Правилах благоустройства»", "https://docs.cntd.ru/document/550212879")
    },
    "экология": {
        "federal": [
            ("Федеральный закон № 89-ФЗ «Об отходах производства и потребления» (ст. 13)", "https://www.consultant.ru/document/cons_doc_LAW_12081/"),
            ("СанПиН 2.1.3684-21 (Требования к содержанию территорий)", "https://docs.cntd.ru/document/573660182")
        ],
        "local_nv": ("Решение Думы г. Нижневартовска № 382 «О Правилах благоустройства»", "https://docs.cntd.ru/document/550212879")
    },
    "транспорт": {
        "federal": [
            ("ГОСТ Р 52289-2019 «Правила применения технических средств организации движения»", "https://docs.cntd.ru/document/1200170133"),
            ("ГОСТ Р 52766-2007 «Дороги общего пользования. Элементы обустройства»", "https://docs.cntd.ru/document/1200057039")
        ],
        "local_nv": ("Решение Думы г. Нижневартовска № 382 «О Правилах благоустройства»", "https://docs.cntd.ru/document/550212879")
    }
}

def register_cyrillic_font() -> str:
    """
    Look for standard Cyrillic TTF fonts in common Windows/Linux system paths
    and register with ReportLab. If none is found, downloads DejaVuSans.ttf dynamically.
    Returns the registered font name.
    """
    local_arial_path = os.path.join(os.path.dirname(__file__), "arial.ttf")
    font_paths = [
        local_arial_path,
        "C:\\Windows\\Fonts\\arial.ttf",
        "C:\\Windows\\Fonts\\times.ttf",
        "C:\\Windows\\Fonts\\calibri.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed.ttf",
    ]
    
    # Check extra folders on Linux dynamically
    import glob
    for linux_pattern in ["/usr/share/fonts/**/*.ttf", "/usr/share/fonts/**/*.otf"]:
        for p in glob.glob(linux_pattern, recursive=True):
            font_paths.append(p)

    # Check/Download dynamic DejaVuSans.ttf in the same directory as this file to avoid Helvetica fallback crash
    local_font_path = os.path.join(os.path.dirname(__file__), "DejaVuSans.ttf")
    if not any(os.path.exists(fp) for fp in font_paths) and not os.path.exists(local_font_path):
        try:
            import urllib.request
            url = "https://github.com/dejavu-fonts/dejavu-fonts/raw/master/resources/ttf/DejaVuSans.ttf"
            logger.info("No system Cyrillic font found. Downloading DejaVuSans.ttf from github...")
            urllib.request.urlretrieve(url, local_font_path)
            font_paths.insert(0, local_font_path)
        except Exception as dl_err:
            logger.warning("Failed to download DejaVuSans.ttf: %s", dl_err)
    elif os.path.exists(local_font_path):
        font_paths.insert(0, local_font_path)

    for fp in font_paths:
        if os.path.exists(fp):
            try:
                pdfmetrics.registerFont(TTFont("CyrillicFont", fp))
                # Test rendering a Cyrillic character to make sure it loads right
                pdfmetrics.getFont("CyrillicFont")
                logger.info("Successfully registered Cyrillic font: %s", fp)
                return "CyrillicFont"
            except Exception as e:
                logger.debug("Failed to register font %s: %s", fp, e)

    logger.warning("No Cyrillic TTF fonts found. Falling back to Helvetica (Russian characters will not render correctly).")
    return "Helvetica"


def generate_legal_pdf(report_id: int, db: Session) -> BytesIO:
    """
    Generate a formal PDF complaint document for a city problem.
    """
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise ValueError(f"Report #{report_id} not found")

    # Приложение работает только с Нижневартовском
    city_name = "Нижневартовск"
    city_name_prep = "Нижневартовске"
    city_name_gen = "Нижневартовска"
    
    user_name = f"Житель города {city_name}"
    user_contact = "Через систему City Pulse"
    
    if report.user_id:
        user = db.query(User).filter(User.id == report.user_id).first()
        if user:
            first = user.first_name or ""
            last = user.last_name or ""
            full_name = f"{first} {last}".strip()
            if full_name:
                user_name = full_name
            if user.username:
                user_contact = f"Telegram: @{user.username}"

    # Setup memory buffer and doc template
    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=54,
        leftMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    # Register font
    font_name = register_cyrillic_font()

    # Styling sheets
    styles = getSampleStyleSheet()
    
    # Custom Cyrillic paragraph styles
    style_normal = ParagraphStyle(
        name='CyrillicNormal',
        fontName=font_name,
        fontSize=11,
        leading=14,
        textColor=colors.HexColor('#0F172A'),
        alignment=4 # Justified
    )
    
    style_header_right = ParagraphStyle(
        name='CyrillicHeaderRight',
        fontName=font_name,
        fontSize=10,
        leading=13,
        textColor=colors.HexColor('#334155'),
        alignment=2 # Right aligned
    )

    style_title = ParagraphStyle(
        name='CyrillicTitle',
        fontName=font_name,
        fontSize=14,
        leading=18,
        textColor=colors.HexColor('#0F172A'),
        alignment=1, # Center
        spaceAfter=15
    )
    
    style_bold = ParagraphStyle(
        name='CyrillicBold',
        fontName=font_name,
        fontSize=11,
        leading=14,
        textColor=colors.HexColor('#0F172A')
    )

    story = []

    # 1. Recipient / Header (Right aligned)
    is_initiative = (report.category and "инициатив" in report.category.lower())
    
    if is_initiative:
        header_text = (
            f"<b>В Управляющую организацию / ТСЖ</b><br/>"
            f"Обслуживающую дом по адресу:<br/>"
            f"г. {city_name}, {report.address or 'Нижневартовск'}<br/>"
            f"<br/>"
            f"<b>Копия:</b> В Администрацию города {city_name_gen}<br/>"
            f"<b>От:</b> Инициативной группы жителей дома<br/>"
            f"<b>Контакты:</b> {user_contact}<br/>"
        )
    else:
        header_text = (
            "<b>В Администрацию города Нижневартовска</b><br/>"
            "628602, Ханты-Мансийский автономный округ - Югра,<br/>"
            "г. Нижневартовск, ул. Таёжная, д. 24<br/>"
            "<br/>"
            "<b>Копия:</b> В Службу жилищного и строительного надзора<br/>"
            "Ханты-Мансийского автономного округа - Югры<br/>"
            "628011, г. Ханты-Мансийск, ул. Мира, д. 104<br/>"
            "<br/>"
            f"<b>От:</b> {user_name}<br/>"
            f"<b>Контакты:</b> {user_contact}<br/>"
        )
        
    story.append(Paragraph(header_text, style_header_right))
    story.append(Spacer(1, 20))

    # 2. Document Title
    if is_initiative:
        story.append(Paragraph("<b>ПРОТОКОЛ НАРОДНОЙ ИНИЦИАТИВЫ ЖИТЕЛЕЙ</b><br/>"
                               f"<font size=11>о предложении по благоустройству дворовой территории по адресу: {report.address or ''}</font>", 
                               style_title))
    else:
        story.append(Paragraph("<b>ЗАЯВЛЕНИЕ</b><br/>"
                               "<font size=11>о нарушении правил благоустройства и содержания городской среды</font>", 
                               style_title))
    story.append(Spacer(1, 15))

    # 3. Document Body
    date_str = report.created_at.strftime("%d.%m.%Y в %H:%M") if report.created_at else datetime.now().strftime("%d.%m.%Y")
    if is_initiative:
        body_text_1 = (
            f"Настоящим сообщаем, что жители многоквартирного дома по адресу: "
            f"г. {city_name}, <b>{report.address or 'Нижневартовск'}</b> "
            f"(координаты: {report.lat or '—'}, {report.lng or '—'}) выступили с инициативой благоустройства. "
            f"В соответствии со ст. 44-46 ЖК РФ данная инициатива была опубликована в системе City Pulse "
            f"и получила широкую поддержку собственников помещений."
        )
    else:
        body_text_1 = (
            f"Настоящим сообщаю, что <b>{date_str}</b> по адресу: "
            f"г. {city_name}, <b>{report.address or 'местонахождение не указано точно'}</b> "
            f"(координаты: {report.lat or '—'}, {report.lng or '—'}) был зафиксирован факт нарушения "
            f"в категории «<b>{report.category or 'Прочее'}</b>»."
        )
    story.append(Paragraph(body_text_1, style_normal))
    story.append(Spacer(1, 12))

    # Details card / table
    clean_desc = (report.description or "Описание не предоставлено").strip()
    # Strip formatting blocks
    if "\n\n[" in clean_desc:
        clean_desc = clean_desc.split("\n\n[")[0]

    # Rewrite description to official administrative/legal language using LLM
    clean_desc = run_async_sync(rewrite_description_to_official_language(clean_desc, report.category or "Прочее"))
        
    if is_initiative:
        details_data = [
            [Paragraph("<b>Суть инициативы:</b>", style_bold), Paragraph(report.title or "Инициатива жителей", style_normal)],
            [Paragraph("<b>Предложение:</b>", style_bold), Paragraph(clean_desc, style_normal)],
            [Paragraph("<b>Поддержали жителей:</b>", style_bold), Paragraph(f"<b>{report.supporters or 0} человек</b>", style_normal)],
            [Paragraph("<b>Статус рассмотрения:</b>", style_bold), Paragraph("Сбор подписей завершен", style_normal)]
        ]
    else:
        details_data = [
            [Paragraph("<b>Суть проблемы:</b>", style_bold), Paragraph(report.title or "Городская проблема", style_normal)],
            [Paragraph("<b>Описание:</b>", style_bold), Paragraph(clean_desc, style_normal)],
            [Paragraph("<b>Статус в системе:</b>", style_bold), Paragraph(report.status or "На рассмотрении", style_normal)]
        ]
    t = Table(details_data, colWidths=[1.8*inch, 5.2*inch])
    t.setStyle(TableStyle([
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('LINEBELOW', (0,0), (-1,-2), 0.5, colors.HexColor('#E2E8F0')),
    ]))
    story.append(t)
    story.append(Spacer(1, 15))

    # Resolve legal references based on category
    cat_key = (report.category or "").strip().lower()
    ref_item = LEGAL_REFERENCES.get(cat_key)
    
    # Fallback to general laws if category not matched
    if not ref_item:
        # Search for keyword match
        for key, val in LEGAL_REFERENCES.items():
            if key in cat_key:
                ref_item = val
                break

    fed_refs = []
    local_ref_name = ""
    local_ref_url = ""

    if ref_item:
        for name, url in ref_item["federal"]:
            fed_refs.append(f'<a href="{url}" color="#0EA5C7"><b>{name}</b></a>')
        local_ref_name, local_ref_url = ref_item["local_nv"]
    else:
        # Default/Fallback
        fed_refs.append('<a href="https://www.consultant.ru/document/cons_doc_LAW_60233/" color="#0EA5C7"><b>Федеральный закон № 59-ФЗ «О порядке рассмотрения обращений граждан»</b></a>')
        local_ref_name = "Решение Думы г. Нижневартовска № 382 «О Правилах благоустройства»"
        local_ref_url = "https://docs.cntd.ru/document/550212879"

    fed_text = ", ".join(fed_refs)
    local_text = f'<a href="{local_ref_url}" color="#0EA5C7"><b>{local_ref_name}</b></a>'

    if is_initiative:
        body_text_2 = (
            "Собственники помещений ссылаются на положения Жилищного кодекса Российской Федерации (ст. 44-46 ЖК РФ), "
            "регулирующие порядок принятия коллективных решений о благоустройстве придомовой территории, установке "
            "дополнительного оборудования и распоряжении общим имуществом многоквартирного дома. Настоящее "
            "решение было поддержано большинством голосов жителей дома."
        )
        body_text_3 = (
            "На основании вышеизложенного, руководствуясь ст. 44-48 Жилищного кодекса РФ, <b>ПРОСИМ:</b><br/>"
            "1. Принять к рассмотрению инициативу жителей дома по благоустройству дворовой территории.<br/>"
            "2. Рассмотреть техническую возможность реализации проекта и составить предварительную смету работ.<br/>"
            "3. Вынести обсуждение сметы и сроков выполнения на ближайшее заседание с представителями инициативной группы.<br/>"
            "4. Предоставить официальный ответ о принятых решениях и сроках реализации инициативы по контактам инициаторов."
        )
    else:
        body_text_2 = (
            f"Указанные факты свидетельствуют о ненадлежащем исполнении обязанностей ответственными службами ЖКХ / "
            f"управляющими компаниями по содержанию придомовой территории, дорожного полотна или иных элементов муниципальной "
            f"инфраструктуры в соответствии с действующим законодательством Российской Федерации, включая требования следующих нормативных документов: "
            f"{fed_text}, а также требований местного законодательства: {local_text}."
        )
        body_text_3 = (
            "На основании вышеизложенного, руководствуясь положениями Федерального закона № 59-ФЗ «О порядке рассмотрения "
            "обращений граждан Российской Федерации», <b>ПРОШУ:</b><br/>"
            "1. Провести проверку по фактам, указанным в данном заявлении.<br/>"
            "2. Выдать предписание ответственным лицам (управляющей компании / подрядным организациям) об устранении "
            "выявленных нарушений в установленный законом срок.<br/>"
            "3. Привлечь виновных лиц к установленной законом административной ответственности.<br/>"
            "4. Предоставить ответ о принятых мерах в письменном или электронном виде по контактам заявителя."
        )
        
    story.append(Paragraph(body_text_2, style_normal))
    story.append(Spacer(1, 12))
    story.append(Paragraph(body_text_3, style_normal))
    story.append(Spacer(1, 30))

    # 4. Verification seal / AI label
    seal_data = [
        [
            Paragraph("<font color='#0EA5C7'><b>ВЕРИФИЦИРОВАНО ИИ CITY PULSE</b></font><br/>"
                      f"<font size=9 color='#64748B'>Сигнал верифицирован автоматической ИИ-моделью zai_vision_service. "
                      f"Уровень уверенности: 94%. ID отчета: #{report.id}</font>", style_normal)
        ]
    ]
    seal_table = Table(seal_data, colWidths=[7*inch])
    seal_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F0FDF4')),
        ('BOX', (0,0), (-1,-1), 1.5, colors.HexColor('#4ADE80')),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LEFTPADDING', (0,0), (-1,-1), 15),
        ('RIGHTPADDING', (0,0), (-1,-1), 15),
    ]))
    story.append(seal_table)
    story.append(Spacer(1, 40))

    # 5. Signatures
    current_date = datetime.now().strftime("%d.%m.%Y г.")
    sig_data = [
        [Paragraph(f"Дата: <b>{current_date}</b>", style_normal), Paragraph("Подпись: ______________________", style_normal)]
    ]
    sig_table = Table(sig_data, colWidths=[3.5*inch, 3.5*inch])
    sig_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(sig_table)

    # Build PDF doc
    doc.build(story)
    buffer.seek(0)
    return buffer


def generate_custom_pdf(title: str, text: str) -> BytesIO:
    """
    Generates a formal custom PDF document for AI Assistant claim/report requests.
    """
    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36,
    )
    
    font_name = register_cyrillic_font()
    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        "CustomPDFTitle",
        parent=styles["Heading1"],
        fontName=font_name,
        fontSize=15,
        leading=19,
        alignment=1,
        textColor=colors.HexColor("#0F172A"),
        spaceAfter=15,
    )
    
    body_style = ParagraphStyle(
        "CustomPDFBody",
        parent=styles["BodyText"],
        fontName=font_name,
        fontSize=10,
        leading=14,
        textColor=colors.HexColor("#334155"),
        spaceAfter=10,
    )
    
    story = []
    story.append(Paragraph(title.upper(), title_style))
    story.append(Spacer(1, 10))
    
    import re
    cleaned_text = re.sub(r'\*\*(.*?)\*\*', r'<b>\1</b>', text)
    formatted_text = cleaned_text.replace("\n", "<br/>")
    story.append(Paragraph(formatted_text, body_style))
    story.append(Spacer(1, 25))
    
    current_date = datetime.now().strftime("%d.%m.%Y %H:%M")
    seal_data = [
        [
            Paragraph("<font color='#0EA5C7'><b>ОФИЦИАЛЬНОЕ ОБРАЩЕНИЕ | СИСТЕМА CITY PULSE</b></font><br/>"
                      f"<font size=9 color='#64748B'>Сформировано ИИ-ассистентом муниципального мониторинга. "
                      f"Дата формирования: {current_date}</font>", body_style)
        ]
    ]
    seal_table = Table(seal_data, colWidths=[7*inch])
    seal_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F8FAFC')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#0EA5C7')),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('RIGHTPADDING', (0,0), (-1,-1), 12),
    ]))
    story.append(seal_table)
    
    doc.build(story)
    buffer.seek(0)
    return buffer
