# scripts/maintenance/generate_marketing_pdf.py
import os
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

def build_pdf():
    pdf_path = r"C:\Users\рс\Desktop\citypulse_marketing_plan.pdf"
    
    # Register system Arial font to support Cyrillic characters
    font_path = "C:\\Windows\\Fonts\\arial.ttf"
    font_bold_path = "C:\\Windows\\Fonts\\arialbd.ttf"
    
    if os.path.exists(font_path):
        pdfmetrics.registerFont(TTFont('Arial', font_path))
        main_font = 'Arial'
    else:
        main_font = 'Helvetica' # Fallback
        
    if os.path.exists(font_bold_path):
        pdfmetrics.registerFont(TTFont('Arial-Bold', font_bold_path))
        bold_font = 'Arial-Bold'
    else:
        bold_font = 'Helvetica-Bold'

    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=letter,
        rightMargin=40, leftMargin=40, topMargin=40, bottomMargin=40
    )
    
    styles = getSampleStyleSheet()
    
    # Custom styles supporting Cyrillic Arial font
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName=bold_font,
        fontSize=22,
        textColor=colors.HexColor('#0F172A'),
        spaceAfter=15,
        alignment=1 # Center
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName=main_font,
        fontSize=12,
        textColor=colors.HexColor('#475569'),
        spaceAfter=30,
        alignment=1
    )
    
    h1_style = ParagraphStyle(
        'Heading1_Custom',
        parent=styles['Normal'],
        fontName=bold_font,
        fontSize=15,
        textColor=colors.HexColor('#1E3A8A'),
        spaceBefore=15,
        spaceAfter=10,
        keepWithNext=True
    )
    
    body_style = ParagraphStyle(
        'Body_Custom',
        parent=styles['Normal'],
        fontName=main_font,
        fontSize=10,
        textColor=colors.HexColor('#334155'),
        spaceAfter=8,
        leading=14
    )
    
    bullet_style = ParagraphStyle(
        'Bullet_Custom',
        parent=body_style,
        leftIndent=15,
        firstLineIndent=-10,
        spaceAfter=4
    )
    
    table_text_style = ParagraphStyle(
        'TableText',
        parent=styles['Normal'],
        fontName=main_font,
        fontSize=9,
        textColor=colors.HexColor('#1E293B'),
        leading=11
    )
    
    table_header_style = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName=bold_font,
        fontSize=9,
        textColor=colors.white,
        leading=11
    )

    story = []
    
    # --- PAGE 1: TITLE & EXECUTIVE SUMMARY ---
    story.append(Spacer(1, 20))
    story.append(Paragraph("СТРАТЕГИЯ МАРКЕТИНГА С МИНИМАЛЬНЫМ БЮДЖЕТОМ", title_style))
    story.append(Paragraph("Приложение «Пульс Города» (Нижневартовск) | План выхода на 1000 VIP-клиентов", subtitle_style))
    story.append(Spacer(1, 10))
    
    story.append(Paragraph("1. Анализ безубыточности (Выход в плюс)", h1_style))
    story.append(Paragraph("<b>Фиксированные ежемесячные затраты:</b>", body_style))
    story.append(Paragraph("• Аренда VPS-сервера (Timeweb Cloud): 2 500 руб.", bullet_style))
    story.append(Paragraph("• Сторонние ИИ-сервисы (OpenRouter, ElevenLabs, прокси): 1 000 руб.", bullet_style))
    story.append(Paragraph("• <b>Итого постоянных трат: 3 500 руб/месяц.</b>", bullet_style))
    story.append(Spacer(1, 5))
    
    story.append(Paragraph("<b>Финансовая модель VIP-пользователя (199 руб/мес):</b>", body_style))
    story.append(Paragraph("• Налог (НПД/УСН 6%) + эквайринг (ЮКасса 3.5%) = 9.5% (18.9 руб).", bullet_style))
    story.append(Paragraph("• Затраты на API для VIP (в среднем): 15 руб/месяц.", bullet_style))
    story.append(Paragraph("• Расходы на 10 Freemium-пользователей (из расчета пропорции 1:10): 10 * 1 руб = 10 руб.", bullet_style))
    story.append(Paragraph("• <b>Чистая маржинальность с одной подписки: 155.1 руб.</b>", bullet_style))
    story.append(Spacer(1, 5))
    
    story.append(Paragraph("<b>Точка безубыточности:</b>", body_style))
    story.append(Paragraph("Для полного покрытия расходов в 3 500 руб. требуется привлечь всего <b>23 активных VIP-пользователя</b> (при 230 бесплатных). Все последующие подписки приносят чистую прибыль, которая полностью реинвестируется в рекламу.", body_style))
    
    story.append(Paragraph("2. План продвижения в Telegram-пабликах Нижневартовска", h1_style))
    story.append(Paragraph("Нижневартовск имеет концентрированную аудиторию в локальных новостных Telegram-каналах. Ниже представлен оптимальный список для размещения рекламных постов с ценами и охватами:", body_style))
    
    # Channels Table
    data = [
        [Paragraph("<b>Название канала</b>", table_header_style), 
         Paragraph("<b>Охват поста</b>", table_header_style), 
         Paragraph("<b>Цена (руб)</b>", table_header_style), 
         Paragraph("<b>Формат</b>", table_header_style)]
    ]
    
    channels = [
        ("Привет, сей час Нижневартовск", "15k - 20k", "2 500", "Пост + репост в чат"),
        ("Нижневартовск | Происшествия", "8k - 10k", "1 500", "Картинка + текст"),
        ("ЧП в Нижневартовске", "7k - 9k", "1 200", "Нативный пост"),
        ("Типичный Нижневартовск", "9k - 12k", "1 800", "Закреп на 24 часа"),
        ("Мегаполис Югра (НВ)", "5k - 7k", "900", "Интеграция в дайджест")
    ]
    
    for name, reach, price, fmt in channels:
        data.append([
            Paragraph(name, table_text_style),
            Paragraph(reach, table_text_style),
            Paragraph(price, table_text_style),
            Paragraph(fmt, table_text_style)
        ])
        
    t = Table(data, colWidths=[200, 100, 80, 130])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1E3A8A')),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('BOTTOMPADDING', (0,0), (-1,0), 6),
        ('TOPPADDING', (0,0), (-1,0), 6),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('BACKGROUND', (0,1), (-1,-1), colors.HexColor('#F8FAFC')),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F1F5F9')]),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    
    story.append(t)
    story.append(PageBreak())
    
    # --- PAGE 2: GUERRILLA MARKETING & TIMELINE ---
    story.append(Paragraph("3. Нестандартные («партизанские») ходы продвижения", h1_style))
    story.append(Paragraph("В условиях нулевого стартового бюджета ключевая ставка делается на виральность и триггеры:", body_style))
    story.append(Paragraph("1. <b>Информер потерянных собак:</b> В пабликах собаководов и зоозащитников Нижневартовска («Потеряшки НВ», «Право на жизнь») размещается инструкция: <i>«Как найти собаку по городским камерам за 2 минуты с помощью ИИ»</i>. Инструмент бесплатен, но для постоянного слежения требуется VIP.", bullet_style))
    story.append(Paragraph("2. <b>Вирусные мемы о проблемах города:</b> Генератор мемов приложения автоматически брендирует картинки. Жители сами делятся мемами в чатах ТСЖ и локальных пабликах, создавая бесплатный вирусный охват.", bullet_style))
    story.append(Paragraph("3. <b>Аудит квитанций ЖКХ:</b> Запуск челленджа в местных чатах: <i>«Проверь свою УК на переплату»</i>. Пользователи бесплатно загружают квитанцию, ИИ выдает юридический отчет по тарифам ХМАО. Это привлекает самую платежеспособную взрослую аудиторию.", bullet_style))
    story.append(Paragraph("4. <b>Интеграция с автолюбителями НВ:</b> В группах «Дороги Нижневартовска» публикуется информация о ямах по ГОСТу. Водители используют приложение, чтобы жалобы автоматически улетали в Госавтоинспекцию.", bullet_style))
    
    story.append(Paragraph("4. Календарный план реинвестирования и сроки (1000 VIP)", h1_style))
    story.append(Paragraph("<b>Модель роста с 100% реинвестированием прибыли в рекламу:</b>", body_style))
    
    # Financial growth timeline table
    timeline_data = [
        [Paragraph("<b>Этап</b>", table_header_style), 
         Paragraph("<b>VIP-пользователи</b>", table_header_style), 
         Paragraph("<b>Бюджет рекламы (руб)</b>", table_header_style), 
         Paragraph("<b>Действия и каналы</b>", table_header_style)]
    ]
    
    timeline = [
        ("Месяц 1", "30", "1 150", "Органический старт, партизанские посевы в группах ЖКХ и потеряшек."),
        ("Месяц 2", "70", "7 350", "Покупка рекламы в мелких пабликах (ЧП НВ, Мегаполис). Рост за счет мемов."),
        ("Месяц 3", "180", "24 400", "Закупка рекламы в крупнейшем паблике «Привет, сей час НВ». Запуск ЖКХ-челленджа."),
        ("Месяц 4", "410", "60 100", "Кросс-продвижение, таргетированные посевы. Масштабирование виральности."),
        ("Месяц 5", "850", "128 300", "Доминирование в инфополе города. Массовые упоминания во всех СМИ НВ."),
        ("Месяц 6", "1 000+", "151 600+", "<b>Цель достигнута. Переход на чистую прибыль (150к+ руб/мес).</b>")
    ]
    
    for stage, vips, budget, desc in timeline:
        timeline_data.append([
            Paragraph(stage, table_text_style),
            Paragraph(vips, table_text_style),
            Paragraph(budget, table_text_style),
            Paragraph(desc, table_text_style)
        ])
        
    t2 = Table(timeline_data, colWidths=[60, 110, 110, 230])
    t2.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#0F172A')),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('BOTTOMPADDING', (0,0), (-1,0), 6),
        ('TOPPADDING', (0,0), (-1,0), 6),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('BACKGROUND', (0,1), (-1,-1), colors.HexColor('#F8FAFC')),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F1F5F9')]),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    
    story.append(t2)
    
    # Build document
    doc.build(story)
    print("✓ Marketing PDF generated successfully at C:\\Users\\рс\\Desktop\\citypulse_marketing_plan.pdf")

if __name__ == "__main__":
    build_pdf()
