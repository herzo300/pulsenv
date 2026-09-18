# services/business/email_service.py
import os
import smtplib
import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from sqlalchemy.orm import Session

from services.data_layer.models import Report
from services.business.pdf_generator import generate_legal_pdf

logger = logging.getLogger(__name__)

# SMTP Server Configurations (typically loaded from .env)
SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.yandex.ru")
SMTP_PORT = int(os.getenv("SMTP_PORT", "465"))
SMTP_USER = os.getenv("SMTP_USER", "citypulse.notifications@yandex.ru")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "mock_smtp_pass_123")
TARGET_UK_EMAIL_FALLBACK = os.getenv("TARGET_UK_EMAIL_FALLBACK", "jkh_nizhnevartovsk_test@mail.ru")

async def check_and_send_collective_email(report_id: int, db: Session) -> bool:
    """Verify if support threshold is reached (10+) and dispatch collective PDF claim to UK email."""
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        logger.error(f"Report #{report_id} not found during auto-email dispatch.")
        return False
        
    # Check threshold and duplicate dispatch guard
    supporters_count = report.supporters or 0
    if supporters_count < 10:
        logger.info(f"Report #{report_id} has {supporters_count} supporters. Need 10 to dispatch.")
        return False
        
    if report.status == "sent_to_uk":
        logger.info(f"Report #{report_id} already dispatched to UK. Skipping.")
        return False

    logger.info(f"🚀 Report #{report_id} reached 10+ supporters ({supporters_count}). Dispatching collective email...")
    
    # 1. Generate the official PDF attachment
    try:
        pdf_buffer = generate_legal_pdf(report_id, db)
        pdf_bytes = pdf_buffer.getvalue()
    except Exception as e:
        logger.error(f"Failed to generate legal PDF for email attachment: {e}")
        return False
        
    # 2. Build email body
    uk_name = report.uk_name or "Управляющая компания"
    subject = f"Коллективное обращение жителей: {report.title or 'Городская проблема'} (Адрес: {report.address or 'Нижневартовск'})"
    
    body = (
        f"Здравствуйте!\n\n"
        f"Направляем вам коллективное обращение собственников жилья по адресу: {report.address or 'Нижневартовск'}.\n"
        f"Данное обращение было сформировано автоматически в системе городского мониторинга City Pulse "
        f"после того, как его поддержали более 10 жителей вашего района (текущее число подписей: {supporters_count}).\n\n"
        f"Суть проблемы: {report.title}\n"
        f"Описание: {report.description}\n\n"
        f"Официальный подписанный протокол ОСС со всеми ссылками на законодательство РФ (ЖК РФ, СанПиН, ГОСТ) "
        f"находится во вложении к этому письму.\n\n"
        f"Просим вас рассмотреть обращение в установленный законом срок и направить официальный ответ инициаторам.\n\n"
        f"С уважением,\n"
        f"Инициативная группа жителей дома & робот-ассистент City Pulse."
    )
    
    # 3. Setup MIME message
    msg = MIMEMultipart()
    msg["From"] = SMTP_USER
    msg["To"] = TARGET_UK_EMAIL_FALLBACK # In production, this can map dynamically to UK emails
    msg["Subject"] = subject
    msg.attach(MIMEText(body, "plain", "utf-8"))
    
    # Attach PDF file
    part = MIMEBase("application", "octet-stream")
    part.set_payload(pdf_bytes)
    encoders.encode_base64(part)
    
    filename = f"collective_claim_{report_id}.pdf"
    part.add_header(
        "Content-Disposition",
        f"attachment; filename={filename}",
    )
    msg.attach(part)
    
    # 4. Connect to SMTP server and send
    if not SMTP_PASSWORD or SMTP_PASSWORD == "mock_smtp_pass_123":
        logger.warning("SMTP credentials are not configured. Logging email dispatch (Mock sandbox mode).")
        # Simulate successful dispatch in local/dev setup
        report.status = "sent_to_uk"
        db.commit()
        logger.info(f"✅ Collective email successfully simulated and logged for report #{report_id}.")
        return True
        
    try:
        # Use SSL connection
        with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT, timeout=15) as server:
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.sendmail(SMTP_USER, [TARGET_UK_EMAIL_FALLBACK], msg.as_string())
            
        # Update report status to prevent duplicate sends
        report.status = "sent_to_uk"
        db.commit()
        
        logger.info(f"✅ Collective email successfully dispatched to UK for report #{report_id}.")
        return True
    except Exception as e:
        logger.error(f"Failed to send collective email via SMTP: {e}")
        return False
