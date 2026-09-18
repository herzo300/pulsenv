# -*- coding: utf-8 -*-
import os
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm, cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

def register_cyrillic_fonts():
    font_paths = [
        ("Arial", "C:/Windows/Fonts/arial.ttf"),
        ("Arial-Bold", "C:/Windows/Fonts/arialbd.ttf"),
        ("Arial-Italic", "C:/Windows/Fonts/ariali.ttf"),
        ("Arial-BoldItalic", "C:/Windows/Fonts/arialbi.ttf"),
        ("Times", "C:/Windows/Fonts/times.ttf"),
        ("Times-Bold", "C:/Windows/Fonts/timesbd.ttf"),
        ("Times-Italic", "C:/Windows/Fonts/timesi.ttf"),
    ]
    registered = []
    for name, path in font_paths:
        if os.path.exists(path):
            try:
                pdfmetrics.registerFont(TTFont(name, path))
                registered.append(name)
            except Exception as e:
                print(f"Font {name} load err: {e}")
    return "Arial" if "Arial" in registered else "Helvetica"

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super(NumberedCanvas, self).__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def draw_page_decorations(self, page_count):
        self.saveState()
        # Top Header line
        self.setStrokeColor(colors.HexColor('#0052CC'))
        self.setLineWidth(1.2)
        self.line(20 * mm, 282 * mm, 190 * mm, 282 * mm)
        
        self.setFont("Arial" if "Arial" in pdfmetrics.getRegisteredFontNames() else "Helvetica", 8)
        self.setFillColor(colors.HexColor('#4A5568'))
        self.drawString(20 * mm, 285 * mm, "ОФИЦИАЛЬНОЕ ОБРАЩЕНИЕ • ПРОЕКТ «CITY PULSE / СООБЩИО» Г. НИЖНЕВАРТОВСК")
        
        # Bottom Footer line
        self.setStrokeColor(colors.HexColor('#CBD5E0'))
        self.setLineWidth(0.8)
        self.line(20 * mm, 18 * mm, 190 * mm, 18 * mm)
        
        self.setFont("Arial" if "Arial" in pdfmetrics.getRegisteredFontNames() else "Helvetica", 8)
        self.setFillColor(colors.HexColor('#718096'))
        self.drawString(20 * mm, 13 * mm, "Цифровая платформа мониторинга городской среды «City Pulse» • 2026 г.")
        self.drawRightString(190 * mm, 13 * mm, f"Стр. {self._pageNumber} из {page_count}")
        self.restoreState()

def create_transport_api_letter(output_path):
    base_font = register_cyrillic_fonts()
    bold_font = "Arial-Bold" if "Arial-Bold" in pdfmetrics.getRegisteredFontNames() else base_font
    italic_font = "Arial-Italic" if "Arial-Italic" in pdfmetrics.getRegisteredFontNames() else base_font

    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        leftMargin=20 * mm,
        rightMargin=20 * mm,
        topMargin=22 * mm,
        bottomMargin=22 * mm,
    )

    styles = getSampleStyleSheet()
    
    # Custom Palette
    primary_color = colors.HexColor('#0A2540')
    accent_color = colors.HexColor('#0052CC')
    dark_gray = colors.HexColor('#2D3748')
    light_bg = colors.HexColor('#F7FAFC')
    border_color = colors.HexColor('#E2E8F0')

    title_style = ParagraphStyle(
        'DocTitle',
        fontName=bold_font,
        fontSize=13,
        leading=17,
        alignment=1, # Center
        textColor=primary_color,
        spaceAfter=12,
    )

    subtitle_style = ParagraphStyle(
        'DocSubTitle',
        fontName=bold_font,
        fontSize=10,
        leading=14,
        alignment=1, # Center
        textColor=accent_color,
        spaceAfter=14,
    )

    header_to_style = ParagraphStyle(
        'HeaderTo',
        fontName=base_font,
        fontSize=9.5,
        leading=13.5,
        alignment=2, # Right
        textColor=dark_gray,
    )

    header_to_bold = ParagraphStyle(
        'HeaderToBold',
        fontName=bold_font,
        fontSize=9.5,
        leading=13.5,
        alignment=2, # Right
        textColor=primary_color,
    )

    body_style = ParagraphStyle(
        'DocBody',
        fontName=base_font,
        fontSize=10,
        leading=14.5,
        alignment=4, # Justify
        textColor=dark_gray,
        spaceAfter=8,
        firstLineIndent=6 * mm,
    )

    body_bold = ParagraphStyle(
        'DocBodyBold',
        fontName=bold_font,
        fontSize=10,
        leading=14.5,
        textColor=primary_color,
        spaceAfter=6,
    )

    bullet_style = ParagraphStyle(
        'DocBullet',
        fontName=base_font,
        fontSize=9.5,
        leading=13.5,
        textColor=dark_gray,
        spaceAfter=4,
        leftIndent=8 * mm,
    )

    table_header_style = ParagraphStyle(
        'TableHeader',
        fontName=bold_font,
        fontSize=9,
        leading=12,
        textColor=colors.white,
        alignment=1,
    )

    table_cell_style = ParagraphStyle(
        'TableCell',
        fontName=base_font,
        fontSize=8.5,
        leading=11.5,
        textColor=dark_gray,
    )

    table_cell_bold = ParagraphStyle(
        'TableCellBold',
        fontName=bold_font,
        fontSize=8.5,
        leading=11.5,
        textColor=primary_color,
    )

    story = []

    # 1. Header (Кому / От кого)
    to_text = """
    <b>Главе города Нижневартовска</b><br/>
    <b>В Департамент жилищно-коммунального хозяйства<br/>
    Администрации города Нижневартовска</b><br/>
    <i>(Управление по транспорту и дорожному хозяйству)</i><br/>
    ул. Таежная, д. 24, г. Нижневартовск, ХМАО-Югра, 628602<br/><br/>
    <b>Копия:</b> Директору <b>АО «НПАТ»</b><br/>
    ул. Авиаторов, д. 20, г. Нижневартовск, 628606<br/><br/>
    <b>От кого:</b> Инициативная группа разработчиков<br/>
    городской цифровой платформы <b>«City Pulse / СообщиО»</b><br/>
    (г. Нижневартовск, ХМАО-Югра)
    """

    header_table = Table(
        [
            [
                Paragraph("<b>Исх. № CP-NV-2026/08-01</b><br/>Дата: «12» августа 2026 г.<br/>г. Нижневартовск", ParagraphStyle('DocMeta', fontName=base_font, fontSize=9, leading=13, textColor=colors.HexColor('#718096'))),
                Paragraph(to_text, header_to_style)
            ]
        ],
        colWidths=[65 * mm, 105 * mm]
    )
    header_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 10))

    # 2. Document Title
    story.append(Paragraph("<b>ОФИЦИАЛЬНОЕ ОБРАЩЕНИЕ (ЗАПРОС)</b>", title_style))
    story.append(Paragraph("О предоставлении доступа к открытым данным телематики и API движения муниципального пассажирского транспорта города Нижневартовска для интеграции в социально-городское приложение «City Pulse»", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#CBD5E0'), spaceAfter=10))

    # 3. Context & Background
    story.append(Paragraph("<b>Уважаемое руководство Администрации города Нижневартовска и департаментов!</b>", ParagraphStyle('Salutation', fontName=bold_font, fontSize=10.5, leading=15, textColor=primary_color, spaceAfter=8)))
    
    story.append(Paragraph(
        "В рамках реализации федерального проекта «Умный город» (Smart City), стратегии цифровой трансформации городской среды Ханты-Мансийского автономного округа – Югры и повышения качества жизни горожан, в Нижневартовске успешно разрабатывается и функционирует социально-ориентированное мобильное приложение и интерактивная карта <b>«City Pulse / СообщиО»</b> (далее — «Сити Пульс»).",
        body_style
    ))

    story.append(Paragraph(
        "Приложение «Сити Пульс» объединяет более 40 функциональных городских слоев (ситуационный мониторинг ЖКХ, оперативные предупреждения о дорожных событиях, погодный мониторинг, видеокамеры города, бюро находок и обратная связь жителей с городскими службами).",
        body_style
    ))

    # 4. Problem Statement & Motivation
    story.append(Paragraph("<b>1. Обоснование социальной важности и актуальности запроса</b>", body_bold))
    story.append(Paragraph(
        "Климатические условия города Нижневартовска характеризуются продолжительным зимним периодом с экстремально низкими температурами воздуха (до -40°C ... -45°C). В таких условиях своевременное и точное информирование пассажиров о реальном времени прибытия автобусов на остановочные павильоны, фактическом местоположении подвижного состава и возможных задержках движения является критически важным фактором безопасности здоровья горожан, школьников и маломобильных групп населения.",
        body_style
    ))

    story.append(Paragraph(
        "Интеграция открытых телематических данных городского транспорта в единый интерфейс карты «Сити Пульс» позволит жителям города:",
        body_style
    ))
    story.append(Paragraph("• Отслеживать движение автобусов основных и межквартальных маршрутов (№ 1, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16, 17, 21, 30, 31, 32, 91, 92, 93, 101, 103, 107 и др.) в реальном времени с интерактивным отображением на карте;", bullet_style))
    story.append(Paragraph("• Получать точный расчет времени до прибытия автобуса на конкретную остановку с учетом дорожной обстановки;", bullet_style))
    story.append(Paragraph("• Видеть информацию о низкопольности транспортных средств и приспособленности для лиц с ограниченными возможностями здоровья (ОВЗ);", bullet_style))
    story.append(Paragraph("• Оперативно получать уведомления об изменении схем движения из-за ремонтных работ, дорожно-транспортных происшествий или погодных аномалий.", bullet_style))

    story.append(Spacer(1, 6))

    # 5. Legal Grounding
    story.append(Paragraph("<b>2. Правовые основания запроса</b>", body_bold))
    story.append(Paragraph(
        "Запрос основывается на действующих нормах законодательства Российской Федерации:",
        body_style
    ))
    story.append(Paragraph("1. <b>Федеральный закон от 09.02.2009 № 8-ФЗ</b> «Об обеспечении доступа к информации о деятельности государственных органов и органов местного самоуправления» (ст. 6, 13 о предоставлении общедоступной информации в форме открытых данных);", bullet_style))
    story.append(Paragraph("2. <b>Федеральный закон от 13.07.2015 № 220-ФЗ</b> «Об организации регулярных перевозок пассажиров и багажа автомобильным транспортом и городским наземным электрическим транспортом в Российской Федерации»;", bullet_style))
    story.append(Paragraph("3. <b>Указ Президента РФ от 07.05.2018 № 204</b> в части создания сквозной цифровой инфраструктуры и развития цифровых сервисов для населения регионов России.", bullet_style))

    story.append(Spacer(1, 6))

    # 6. Technical Specifications Requested
    story.append(Paragraph("<b>3. Запрашиваемые технические форматы и параметры подключения (API)</b>", body_bold))
    story.append(Paragraph(
        "Для организации бесшовного некоммерческого обмена данными просим предоставить доступ к любому из имеющихся в распоряжении Администрации / ЦДС / РНИС ХМАО-Югры / АО «НПАТ» форматов телематики:",
        body_style
    ))

    # Table of Technical Formats
    tech_data = [
        [Paragraph("Вариант интеграции", table_header_style), Paragraph("Формат / Протокол", table_header_style), Paragraph("Описание передаваемых параметров", table_header_style)],
        [
            Paragraph("<b>Вариант А<br/>(Приоритетный)</b>", table_cell_bold),
            Paragraph("<b>GTFS-Realtime</b><br/>(VehiclePositions, TripUpdates, Alerts)", table_cell_style),
            Paragraph("Международный открытый стандарт транзитных данных: геопозиция (Lat, Lon), ID маршрута, госномер/бортномер, азимут, задержка по графику.", table_cell_style)
        ],
        [
            Paragraph("<b>Вариант Б</b>", table_cell_bold),
            Paragraph("<b>REST API (JSON)</b><br/>(HTTP GET / WebSocket)", table_cell_style),
            Paragraph("Эндпоинты геопозиций автобусов в онлайн-режиме, расписание, реестр остановок, признак доступности для инвалидов (низкопольный транспорт).", table_cell_style)
        ],
        [
            Paragraph("<b>Вариант В</b>", table_cell_bold),
            Paragraph("<b>РНИС ХМАО-Югра / АСУ-Навигация</b>", table_cell_style),
            Paragraph("Поток телематических данных от единого регионального/муниципального навигационного сервера диспетчеризации движения.", table_cell_style)
        ],
    ]

    t = Table(tech_data, colWidths=[38 * mm, 45 * mm, 87 * mm])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), accent_color),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('GRID', (0,0), (-1,-1), 0.5, border_color),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, light_bg]),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t)
    story.append(Spacer(1, 8))

    # 7. Obligations & Non-commercial terms
    story.append(Paragraph("<b>4. Гарантии и обязательства разработчиков</b>", body_bold))
    story.append(Paragraph("• <b>Некоммерческий статус:</b> Доступ к информации о транспорте в приложении «City Pulse» предоставляется всем жителям города <b>абсолютно бесплатно</b>, без подписок и коммерческих барьеров;", bullet_style))
    story.append(Paragraph("• <b>Информационная безопасность:</b> Соблюдение всех технических регламентов по защите каналов передачи данных, отсутствие перегрузки муниципальных серверов (внедрение локального кэширования и проксирования запросов);", bullet_style))
    story.append(Paragraph("• <b>Атрибуция источника:</b> Обязательное указание Администрации города Нижневартовска и АО «НПАТ» как официальных источников открытых данных с размещением городской символики в карточках маршрутов.", bullet_style))

    story.append(Spacer(1, 8))

    # 8. Request & Next Steps
    story.append(Paragraph("<b>ПРОСИМ:</b>", ParagraphStyle('Prosim', fontName=bold_font, fontSize=11, leading=15, textColor=primary_color, spaceAfter=6)))
    story.append(Paragraph("1. Рассмотреть настоящее обращение в установленный законом срок;", bullet_style))
    story.append(Paragraph("2. Предоставить технический доступ (URL эндпоинта, API-ключ / токен авторизации или спецификацию потока данных) к открытым данным мониторинга движения муниципального пассажирского транспорта г. Нижневартовска;", bullet_style))
    story.append(Paragraph("3. Определить ответственное техническое лицо / куратора со стороны Департамента ЖКХ или МКУ для оперативного согласования формата взаимодействия и тестирования интеграции.", bullet_style))

    story.append(Spacer(1, 14))

    # 9. Signatures Block
    sign_data = [
        [
            Paragraph("<b>С уважением,</b><br/>Команда проекта <b>«City Pulse / СообщиО»</b><br/>г. Нижневартовск", ParagraphStyle('SignLeft', fontName=base_font, fontSize=9.5, leading=14, textColor=dark_gray)),
            Paragraph("________________ / Инициатор проекта /<br/><br/><b>Контакты для связи:</b><br/>Эл. почта: <i>citypulse.nv@gmail.com</i><br/>Telegram: <i>@monitornv</i> / <i>@citypulse_nv</i><br/>Веб: <i>soobshio-nv.ru</i>", ParagraphStyle('SignRight', fontName=base_font, fontSize=9, leading=13, textColor=dark_gray))
        ]
    ]
    sign_table = Table(sign_data, colWidths=[90 * mm, 80 * mm])
    sign_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(KeepTogether(sign_table))

    # Build PDF
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF successfully generated at: {output_path}")

if __name__ == '__main__':
    desktop_dir = os.path.join(os.environ.get('USERPROFILE', 'C:/Users/рс'), 'Desktop')
    out_file = os.path.join(desktop_dir, 'Запрос_API_Транспорт_Нижневартовск_CityPulse.pdf')
    create_transport_api_letter(out_file)
