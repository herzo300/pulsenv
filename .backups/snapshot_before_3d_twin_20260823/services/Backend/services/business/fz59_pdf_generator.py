import os
import uuid
import sys
from datetime import datetime
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.units import mm
import textwrap

NIZHNEVARTOVSK_DEPARTMENTS = {
    "uk_1": "Управляющая компания №1 г. Нижневартовск",
    "uk_2": "Управляющая компания №2 г. Нижневартовск",
    "zhkh": "Департамент ЖКХ Администрации г. Нижневартовска",
    "adm": "Главе города Нижневартовска Кощенко Д.А."
}

def _register_cyrillic_font():
    """Registers Arial font for Cyrillic support, or falls back to system fonts."""
    font_name = "Arial"
    try:
        pdfmetrics.getFont(font_name)
        return font_name
    except KeyError:
        # Need to register
        paths = [
            r"C:\Windows\Fonts\arial.ttf",
            r"C:\Windows\Fonts\ARIAL.TTF",
            "/usr/share/fonts/truetype/msttcorefonts/Arial.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/dejavu/DejaVuSans.ttf",
        ]
        # Also check local fonts folder
        local_font = os.path.join(os.path.dirname(__file__), "..", "..", "static", "fonts", "DejaVuSans.ttf")
        paths.append(local_font)

        for path in paths:
            if os.path.exists(path):
                try:
                    pdfmetrics.registerFont(TTFont(font_name, path))
                    return font_name
                except Exception as e:
                    pass
        
        # If no font found, we might have issues with Cyrillic, but let's fallback to Helvetica
        return "Helvetica"

def generate_fz59_pdf(output_path: str, applicant_name: str, applicant_address: str, 
                      applicant_phone: str, department_key: str, category: str, 
                      description: str, location_address: str, lat: float = 0.0, lng: float = 0.0):
    """
    Generates an official complaint PDF (e.g. FZ-59 format) and saves it to output_path.
    """
    # Ensure directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    font_name = _register_cyrillic_font()
    department_name = NIZHNEVARTOVSK_DEPARTMENTS.get(department_key, "В компетентные органы г. Нижневартовска")

    c = canvas.Canvas(output_path, pagesize=A4)
    width, height = A4

    # Helper for drawing text
    def draw_text(text, x, y, size=12, max_width=None):
        c.setFont(font_name, size)
        if not max_width:
            c.drawString(x, y, text)
            return y - size * 1.5

        # Word wrap
        avg_char_width = size * 0.6  # approximation
        max_chars = int(max_width / avg_char_width)
        lines = textwrap.wrap(text, width=max_chars)
        for line in lines:
            c.drawString(x, y, line)
            y -= size * 1.5
        return y

    # Right align header (To whom)
    header_x = width - 80 * mm
    y = height - 20 * mm
    y = draw_text("Кому:", header_x, y, size=11)
    y = draw_text(department_name, header_x, y, size=11, max_width=70*mm)
    y -= 5 * mm
    y = draw_text("От кого:", header_x, y, size=11)
    y = draw_text(applicant_name or "Житель г. Нижневартовска", header_x, y, size=11, max_width=70*mm)
    y = draw_text(applicant_address or "г. Нижневартовск", header_x, y, size=11, max_width=70*mm)
    if applicant_phone:
        y = draw_text(f"Тел: {applicant_phone}", header_x, y, size=11)

    y -= 20 * mm
    
    # Title centered
    c.setFont(font_name, 14)
    c.drawCentredString(width / 2.0, y, "ОФИЦИАЛЬНОЕ ОБРАЩЕНИЕ (ЖАЛОБА)")
    y -= 10 * mm
    c.setFont(font_name, 12)
    c.drawCentredString(width / 2.0, y, f"по категории: {category}")
    y -= 15 * mm

    # Body
    body_x = 20 * mm
    y = draw_text("Суть обращения:", body_x, y, size=12, max_width=170*mm)
    y -= 2 * mm
    y = draw_text(description, body_x, y, size=12, max_width=170*mm)
    y -= 10 * mm
    
    if location_address:
        y = draw_text(f"Адрес проблемы: {location_address}", body_x, y, size=12, max_width=170*mm)
    if lat and lng:
        y = draw_text(f"Координаты: {lat}, {lng}", body_x, y, size=12)
    
    y -= 10 * mm
    y = draw_text("Прошу принять меры по устранению нарушения в установленные законом сроки.", body_x, y, size=12, max_width=170*mm)
    
    y -= 20 * mm
    
    # Footer (Date and Signature)
    date_str = datetime.now().strftime("%d.%m.%Y")
    draw_text(f"Дата: {date_str}", body_x, y, size=12)
    draw_text("Подпись: ____________________", width - 80 * mm, y, size=12)

    c.save()
    return output_path

if __name__ == "__main__":
    # Test
    generate_fz59_pdf(
        "test_appeal.pdf",
        "Иванов И.И.",
        "ул. Ленина 10",
        "+7 900 123 45 67",
        "zhkh",
        "Ямы на дорогах",
        "Огромная яма, невозможно проехать, машины ломают подвеску уже второй месяц.",
        "г. Нижневартовск, ул. Мира 5"
    )
