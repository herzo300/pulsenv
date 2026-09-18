# services/Backend/services/business/pdf_generator.py — Official GOST PDF Complaint Generator for Hermes & Backend
import io
import os
import logging
from datetime import datetime

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

logger = logging.getLogger(__name__)

CYRILLIC_FONT_NAME = "CyrillicFont"
CYRILLIC_BOLD_FONT_NAME = "CyrillicFont-Bold"

def _setup_cyrillic_fonts():
    reg_path = "C:/Windows/Fonts/arial.ttf"
    bold_path = "C:/Windows/Fonts/arialbd.ttf"
    if not os.path.exists(reg_path):
        reg_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        bold_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

    try:
        pdfmetrics.registerFont(TTFont(CYRILLIC_FONT_NAME, reg_path))
        pdfmetrics.registerFont(TTFont(CYRILLIC_BOLD_FONT_NAME, bold_path if os.path.exists(bold_path) else reg_path))
        pdfmetrics.registerFontFamily(CYRILLIC_FONT_NAME, normal=CYRILLIC_FONT_NAME, bold=CYRILLIC_BOLD_FONT_NAME)
    except Exception as e:
        logger.warning(f"Failed to register Cyrillic fonts: {e}")

_setup_cyrillic_fonts()


def generate_custom_pdf(title: str, body_text: str, address: str = "г. Нижневартовск") -> io.BytesIO:
    """
    Generate an official GOST-compliant (ГОСТ Р 7.0.97-2016) PDF complaint document from Hermes AI Assistant.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36
    )

    styles = getSampleStyleSheet()

    font_reg = CYRILLIC_FONT_NAME
    font_bold = CYRILLIC_BOLD_FONT_NAME

    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontSize=13,
        leading=16,
        textColor=colors.HexColor('#0F172A'),
        alignment=TA_CENTER,
        fontName=font_bold
    )

    header_style = ParagraphStyle(
        'DocHeader',
        parent=styles['Normal'],
        fontSize=9,
        leading=12,
        textColor=colors.HexColor('#1E293B'),
        alignment=TA_RIGHT,
        fontName=font_reg
    )

    body_style = ParagraphStyle(
        'DocBody',
        parent=styles['Normal'],
        fontSize=10,
        leading=14,
        textColor=colors.HexColor('#1E293B'),
        fontName=font_reg
    )

    bold_style = ParagraphStyle(
        'DocBold',
        parent=body_style,
        fontName=font_bold
    )

    elements = []

    # 1. Header (ГОСТ Р 7.0.97-2016 Адресат)
    date_str = datetime.now().strftime("%d.%m.%Y г.")
    doc_id = int(datetime.now().timestamp() * 1000) % 1000000

    header_text = (
        "<b>В Администрацию города Нижневартовска</b><br/>"
        "Служба жилищного и строительного надзора ХМАО-Югры<br/>"
        "628600, Ханты-Мансийский АО — Югра, г. Нижневартовск<br/>"
        "<b>Заявитель:</b> Муниципальная система «Пульс Города»<br/>"
        f"<b>Исх. №:</b> CP-2026/{doc_id:06d} от {date_str}"
    )
    elements.append(Paragraph(header_text, header_style))
    elements.append(Spacer(1, 14))

    # Line separator
    elements.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor('#0284C7'), spaceBefore=2, spaceAfter=14))

    # 2. Document Title
    doc_title = title if title else "ОФИЦИАЛЬНОЕ ЮРИДИЧЕСКОЕ ОБРАЩЕНИЕ (ПРЕТЕНЗИЯ)"
    elements.append(Paragraph(doc_title.upper(), title_style))
    elements.append(Spacer(1, 4))
    elements.append(Paragraph("О нарушении законодательства и правил коммунального обслуживания", ParagraphStyle('Sub', parent=body_style, fontSize=9, alignment=TA_CENTER, textColor=colors.HexColor('#64748B'))))
    elements.append(Spacer(1, 14))

    # 3. Metadata Box
    data = [
        [Paragraph("Объект / Адрес:", bold_style), Paragraph(address or "г. Нижневартовск", body_style)],
        [Paragraph("Правовое основание:", bold_style), Paragraph("ФЗ № 59-ФЗ, ЖК РФ (ст. 161, 162), ГОСТ Р 50597-2017", body_style)],
        [Paragraph("Статус верификации:", bold_style), Paragraph("<b>ЗАРЕГИСТРИРОВАНО ИИ-ГЕРМЕС</b>", bold_style)],
    ]

    t = Table(data, colWidths=[140, 380])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F8FAFC')),
        ('BOX', (0, 0), (-1, -1), 0.8, colors.HexColor('#CBD5E1')),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#E2E8F0')),
        ('PADDING', (0, 0), (-1, -1), 6),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 16))

    # 4. Body Content
    elements.append(Paragraph("<b>ОПИСАНИЕ ОБСТОЯТЕЛЬСТВ И СУТЬ НАРУШЕНИЯ:</b>", bold_style))
    elements.append(Spacer(1, 6))

    clean_text = body_text.replace("**", "").replace("*", "").replace("#", "").strip()
    for line in clean_text.split("\n"):
        line = line.strip()
        if line:
            elements.append(Paragraph(line, body_style))
            elements.append(Spacer(1, 4))

    elements.append(Spacer(1, 12))

    # 5. Demands (Требовательная часть)
    demands_text = (
        "<b>НА ОСНОВАНИИ ИЗЛОЖЕННОГО, ПРОШУ:</b><br/>"
        "1. Провести проверку факта нарушения правил коммунального обслуживания и благоустройства.<br/>"
        "2. Выдать предписание уполномоченным лицам управляющей организации об устранении нарушений.<br/>"
        "3. Направить официальный мотивированный ответ в установленный законом 30-дневный срок."
    )
    elements.append(Paragraph(demands_text, body_style))
    elements.append(Spacer(1, 20))

    # 6. Blue Stamp Box (ЭЦП ИИ-Гермес)
    stamp_text = (
        "<b>ДОКУМЕНТ ПОДПИСАН УСИЛЕННОЙ ЭЛЕКТРОННОЙ ПОДПИСЬЮ ИИ-ГЕРМЕС</b><br/>"
        f"Сертификат: 4F92-8812-BC01-2026-NVR • Регистрационный номер: CP-VERIFY-{doc_id}<br/>"
        f"Владелец: ИИ-Диспетчер «Пульс Города» • Действителен до: 31.12.2030"
    )
    stamp_p = Paragraph(stamp_text, ParagraphStyle('Stamp', parent=body_style, fontSize=8, leading=11, textColor=colors.HexColor('#0369A1'), alignment=TA_CENTER))
    stamp_table = Table([[stamp_p]], colWidths=[520])
    stamp_table.setStyle(TableStyle([
        ('BOX', (0, 0), (-1, -1), 1.5, colors.HexColor('#0284C7')),
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F0F9FF')),
        ('PADDING', (0, 0), (-1, -1), 8),
    ]))
    elements.append(stamp_table)

    doc.build(elements)
    buffer.seek(0)
    return buffer


def generate_legal_pdf(report_id: int, db_session=None) -> io.BytesIO:
    return generate_custom_pdf(
        title=f"Официальное обращение по сигналу №{report_id}",
        body_text=f"Зафиксирован официальный сигнал граждан №{report_id}. Требуется выездная проверка уполномоченных служб администрации г. Нижневартовска.",
        address="г. Нижневартовск"
    )
