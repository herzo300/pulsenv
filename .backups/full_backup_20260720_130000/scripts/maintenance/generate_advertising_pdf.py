# scripts/maintenance/generate_advertising_pdf.py
import os
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

def build_pdf():
    pdf_path = r"C:\Users\рс\Desktop\citypulse_advertising_plan.pdf"
    
    font_path = "C:\\Windows\\Fonts\\arial.ttf"
    font_bold_path = "C:\\Windows\\Fonts\\arialbd.ttf"
    
    if os.path.exists(font_path):
        pdfmetrics.registerFont(TTFont('Arial', font_path))
        main_font = 'Arial'
    else:
        main_font = 'Helvetica'
        
    if os.path.exists(font_bold_path):
        pdfmetrics.registerFont(TTFont('Arial-Bold', font_bold_path))
        bold_font = 'Arial-Bold'
    else:
        bold_font = 'Helvetica-Bold'

    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=letter,
        rightMargin=45, leftMargin=45, topMargin=45, bottomMargin=45
    )
    
    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName=bold_font,
        fontSize=20,
        textColor=colors.HexColor('#0F172A'),
        spaceAfter=15,
        alignment=1
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName=main_font,
        fontSize=11,
        textColor=colors.HexColor('#475569'),
        spaceAfter=25,
        alignment=1
    )
    
    h1_style = ParagraphStyle(
        'Heading1_Custom',
        parent=styles['Normal'],
        fontName=bold_font,
        fontSize=14,
        textColor=colors.HexColor('#1E3A8A'),
        spaceBefore=12,
        spaceAfter=8,
        keepWithNext=True
    )
    
    body_style = ParagraphStyle(
        'Body_Custom',
        parent=styles['Normal'],
        fontName=main_font,
        fontSize=9.5,
        textColor=colors.HexColor('#334155'),
        spaceAfter=7,
        leading=13.5
    )
    
    bullet_style = ParagraphStyle(
        'Bullet_Custom',
        parent=body_style,
        leftIndent=15,
        firstLineIndent=-10,
        spaceAfter=3
    )
    
    table_text_style = ParagraphStyle(
        'TableText',
        parent=styles['Normal'],
        fontName=main_font,
        fontSize=8.5,
        textColor=colors.HexColor('#1E293B'),
        leading=10
    )
    
    table_header_style = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName=bold_font,
        fontSize=8.5,
        textColor=colors.white,
        leading=10
    )

    story = []
    
    # --- PAGE 1: TITLE & MONTH 1-3 STRATEGY ---
    story.append(Spacer(1, 10))
    story.append(Paragraph("ПОШАГОВЫЙ ПЛАН РЕКЛАМНОЙ КАМПАНИИ ПО МЕСЯЦАМ", title_style))
    story.append(Paragraph("Приложение «Пульс Города» (Нижневартовск) | Стартовый бюджет: 5 000 руб.", subtitle_style))
    
    story.append(Paragraph("Введение и стратегия реинвестирования", h1_style))
    story.append(Paragraph("Данная кампания нацелена на достижение 1000+ платных подписчиков (VIP) за 6 месяцев путем полной капитализации прибыли от первых подписок. Постоянные траты составляют <b>3 500 руб/месяц</b> (2 500 руб. сервер + 1 000 руб. сервисы).", body_style))
    
    story.append(Paragraph("Месяц 1: Запуск и проверка гипотез (Бюджет: 5 000 руб)", h1_style))
    story.append(Paragraph("• <b>Распределение бюджета:</b> Размещение в пабликах «ЧП в Нижневартовске» (1 200 руб.), «Привет, сей час Нижневартовск» (2 500 руб.) и «Мегаполис Югра» (900 руб.). Остаток 400 руб. на мелкие чаты.", bullet_style))
    story.append(Paragraph("• <b>Целевые метрики:</b> Охват рекламных объявлений — 35 000 просмотров. Конверсия в бесплатные установки (3%) — 1 000 скачиваний. Конверсия в VIP-подписку (4% от скачавших) — <b>40 платных подписчиков</b>.", bullet_style))
    story.append(Paragraph("• <b>Финансовый результат:</b> Оборот 7 960 руб. Чистая прибыль за вычетом трат на сервер/сервисы — 4 460 руб. Бюджет на Месяц 2 (реинвест + остаток) — <b>4 860 руб.</b>", bullet_style))
    
    story.append(Paragraph("Месяц 2: Стабилизация и виральность (Бюджет: 4 860 руб)", h1_style))
    story.append(Paragraph("• <b>Распределение бюджета:</b> Размещение в «Типичный Нижневартовск» (1 800 руб.), «Нижневартовск | Происшествия» (1 500 руб.) и повторный пост в «Мегаполис Югра» (900 руб.). Остаток 660 руб. сохраняется.", bullet_style))
    story.append(Paragraph("• <b>Целевые метрики:</b> 35 новых VIP-подписчиков. С учетом удержания 90% VIP первого месяца (36 продлений), общее число платных пользователей достигает <b>71 человека</b>.", bullet_style))
    story.append(Paragraph("• <b>Финансовый результат:</b> Доход 14 129 руб. Чистая прибыль — 10 629 руб. Бюджет на Месяц 3 — <b>10 629 руб.</b>", bullet_style))
    
    story.append(Paragraph("Месяц 3: Агрессивный рост (Бюджет: 10 629 руб)", h1_style))
    story.append(Paragraph("• <b>Распределение бюджета:</b> Два больших размещения в «Привет, сей час Нижневартовск» (5 000 руб.), «Типичный Нижневартовск» (1 800 руб.), «ЧП в НВ» (1 200 руб.) + 2 000 руб. на рекламу в сообществах автомобилистов.", bullet_style))
    story.append(Paragraph("• <b>Целевые метрики:</b> 80 новых VIP-подписчиков. Общая база VIP-клиентов с учетом продлений (удержание 85%) составляет <b>140 человек</b>.", bullet_style))
    story.append(Paragraph("• <b>Финансовый результат:</b> Доход 27 860 руб. Чистая прибыль — 24 360 руб. Бюджет на Месяц 4 — <b>24 360 руб.</b>", bullet_style))
    
    story.append(PageBreak())
    
    # --- PAGE 2: MONTH 4-6 & CHANNELS TABLE ---
    story.append(Paragraph("Месяц 4: Экспансия и авто-клубы (Бюджет: 24 360 руб)", h1_style))
    story.append(Paragraph("• <b>Распределение бюджета:</b> Полноценный охват всех пабликов города (15 000 руб.) + 9 360 руб. на таргетированную рекламу и кросс-продвижение с местными автомойками, детейлинг-центрами и АЗС.", bullet_style))
    story.append(Paragraph("• <b>Целевые метрики:</b> Привлечение 180 новых VIP. Общая база платных пользователей — <b>299 человек</b>.", bullet_style))
    story.append(Paragraph("• <b>Финансовый результат:</b> Доход 59 501 руб. Чистая прибыль — 56 001 руб. Бюджет на Месяц 5 — <b>56 001 руб.</b>", bullet_style))
    
    story.append(Paragraph("Месяц 5: Доминирование и конкурсы (Бюджет: 56 001 руб)", h1_style))
    story.append(Paragraph("• <b>Распределение бюджета:</b> Повторные волны рекламы во всех пабликах (25 000 руб.) + 31 001 руб. на проведение масштабного конкурса с розыгрышем ценных призов (смартфоны, топливные карты) для VIP-подписчиков.", bullet_style))
    story.append(Paragraph("• <b>Целевые метрики:</b> 420 новых VIP. База платных пользователей возрастает до <b>674 человек</b>.", bullet_style))
    story.append(Paragraph("• <b>Финансовый результат:</b> Доход 134 126 руб. Чистая прибыль — 130 626 руб. Бюджет на Месяц 6 — <b>130 626 руб.</b>", bullet_style))
    
    story.append(Paragraph("Месяц 6: Абсолютный охват (Бюджет: 130 626 руб)", h1_style))
    story.append(Paragraph("• <b>Распределение бюджета:</b> Реклама у локальных блогеров Нижневартовска, спонсорство местных мероприятий и массовый охват во всех пабликах ХМАО. Рекламные расходы составляют 130 000 руб.", bullet_style))
    story.append(Paragraph("• <b>Целевые метрики:</b> Привлечение 800 новых VIP-подписчиков. Итоговое количество платных клиентов — <b>1 372 VIP-пользователя</b>.", bullet_style))
    story.append(Paragraph("• <b>Итог:</b> Переход на стабильный оборот более <b>270 000 руб/месяц</b> при постоянных расходах в 3 500 руб.", bullet_style))
    
    story.append(Paragraph("Сводная таблица пошагового плана", h1_style))
    
    table_data = [
        [Paragraph("<b>Месяц</b>", table_header_style), 
         Paragraph("<b>Бюджет (руб)</b>", table_header_style), 
         Paragraph("<b>Новые VIP</b>", table_header_style), 
         Paragraph("<b>Всего VIP</b>", table_header_style), 
         Paragraph("<b>Доход (руб)</b>", table_header_style), 
         Paragraph("<b>Прибыль (руб)</b>", table_header_style)]
    ]
    
    rows = [
        ("Месяц 1", "5 000", "40", "40", "7 960", "4 460"),
        ("Месяц 2", "4 860", "35", "71", "14 129", "10 629"),
        ("Месяц 3", "10 629", "80", "140", "27 860", "24 360"),
        ("Месяц 4", "24 360", "180", "299", "59 501", "56 001"),
        ("Месяц 5", "56 001", "420", "674", "134 126", "130 626"),
        ("Месяц 6", "130 626", "800", "1 372", "273 028", "269 528")
    ]
    
    for month, budget, new_vip, total_vip, rev, profit in rows:
        table_data.append([
            Paragraph(month, table_text_style),
            Paragraph(budget, table_text_style),
            Paragraph(new_vip, table_text_style),
            Paragraph(total_vip, table_text_style),
            Paragraph(rev, table_text_style),
            Paragraph(profit, table_text_style)
        ])
        
    t = Table(table_data, colWidths=[65, 85, 80, 80, 95, 115])
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
    
    # Build document
    doc.build(story)
    print("✓ Advertising Plan PDF generated successfully at C:\\Users\\рс\\Desktop\\citypulse_advertising_plan.pdf")

if __name__ == "__main__":
    build_pdf()
