"""Deduplication and database persistence."""
import re
import logging

from .config import TARGET_CHANNEL

logger = logging.getLogger(__name__)


def _normalize_text_signature(text: str | None) -> str:
    from services.zai_service import make_marker_summary

    cleaned = make_marker_summary(text, max_len=120).lower()
    cleaned = re.sub(r"[^a-zа-яё0-9\s]", " ", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned


def _same_coordinates(lat1, lng1, lat2, lng2) -> bool:
    if None in (lat1, lng1, lat2, lng2):
        return False
    return (
        abs(float(lat1) - float(lat2)) <= 0.0009
        and abs(float(lng1) - float(lng2)) <= 0.0012
    )


def _find_duplicate_report(db, summary, address, lat, lon, category, city=None):
    from datetime import datetime, timedelta

    from services.data_layer.models import Report
    from services.geo_service import sanitize_address_candidate

    week_ago = datetime.utcnow() - timedelta(days=7)
    signature = _normalize_text_signature(summary)
    normalized_address = sanitize_address_candidate(address)

    query = db.query(Report).filter(
        Report.category == category,
        Report.created_at >= week_ago,
    )
    if city:
        query = query.filter(Report.city == city)

    candidates = (
        query.order_by(Report.created_at.desc())
        .limit(80)
        .all()
    )

    for report in candidates:
        report_signature = _normalize_text_signature(report.title or report.description)
        report_address = sanitize_address_candidate(report.address)

        matches_coords = _same_coordinates(lat, lon, report.lat, report.lng)
        matches_address = bool(
            normalized_address
            and report_address
            and normalized_address == report_address
        )
        matches_signature = bool(
            signature
            and report_signature
            and (
                signature == report_signature
                or signature in report_signature
                or report_signature in signature
            )
        )

        if matches_coords and (matches_address or matches_signature or not signature):
            return report
        if matches_address and matches_signature:
            return report

    return None


def _check_duplicate(db, text, address, lat, lon, category):
    """Проверяет дубликаты жалоб по тексту, адресу и координатам"""
    from datetime import datetime, timedelta

    from sqlalchemy import and_, func

    from services.data_layer.models import Report

    # Проверка за последние 7 дней
    week_ago = datetime.utcnow() - timedelta(days=7)

    def _escape_like(s: str) -> str:
        """Escape special LIKE characters to prevent unintended matching."""
        return s.replace("%", "\\%").replace("_", "\\_")

    # По координатам (если есть)
    if lat and lon:
        # Радиус ~100 метров
        lat_diff = 0.0009  # ~100м
        lon_diff = 0.0012  # ~100м
        similar_coords = (
            db.query(Report)
            .filter(
                and_(
                    Report.lat.between(lat - lat_diff, lat + lat_diff),
                    Report.lng.between(lon - lon_diff, lon + lon_diff),
                    Report.category == category,
                    Report.created_at >= week_ago,
                )
            )
            .first()
        )
        if similar_coords:
            return True

    # По адресу (если есть)
    if address:
        addr_normalized = _escape_like(address.lower().strip()[:30])
        similar_addr = (
            db.query(Report)
            .filter(
                and_(
                    func.lower(Report.address).like("%" + addr_normalized + "%"),
                    Report.category == category,
                    Report.created_at >= week_ago,
                )
            )
            .first()
        )
        if similar_addr:
            return True

    # По тексту (первые 50 символов)
    if text and len(text) > 20:
        text_snippet = _escape_like(text[:50].lower().strip())
        similar_text = (
            db.query(Report)
            .filter(
                and_(
                    func.lower(Report.description).like("%" + text_snippet + "%"),
                    Report.category == category,
                    Report.created_at >= week_ago,
                )
            )
            .first()
        )
        if similar_text:
            return True

    return False


async def _check_duplicate_post(client, summary, address, lat, lon, category):
    """Проверяет дубликаты постов в канале перед публикацией"""
    try:
        from datetime import datetime

        # Получаем последние сообщения из канала (за последние 24 часа)
        messages = await client.get_messages(TARGET_CHANNEL, limit=50)
        now = datetime.now()

        for msg in messages:
            if not msg.text:
                continue

            # Проверка по тексту сводки
            if summary and summary[:50].lower() in msg.text.lower():
                return True

            # Проверка по адресу
            if address and address.lower() in msg.text.lower():
                return True

            # Проверка по координатам (если есть)
            if lat and lon:
                coord_str = f"{lat:.4f}, {lon:.4f}"
                if coord_str in msg.text or f"{lat:.3f}" in msg.text:
                    return True

        return False
    except Exception as e:
        logger.debug(f"Duplicate check error: {e}")
        return False


def _determine_city(lat, lng, source, channel) -> str:
    """Приложение работает только с Нижневартовском."""
    return "nizhnevartovsk"


async def save_to_db(
    summary, text, lat, lng, address, category, source, msg_id=None, channel=None, description=None, created_at=None
):
    """Save complaint marker payload and merge repeated public complaints into one report."""
    db = None
    try:
        from services.data_layer.database import SessionLocal
        from services.data_layer.models import Report
        from services.geo_service import sanitize_address_candidate
        from services.zai_service import build_marker_summary
        from datetime import datetime

        db = SessionLocal()

        # Hard deduplication check by (source, telegram_message_id)
        if source and msg_id:
            existing = (
                db.query(Report)
                .filter(
                    Report.source == source,
                    Report.telegram_message_id == str(msg_id)
                )
                .first()
            )
            if existing:
                logger.info(
                    "Hard duplicate check: Report with source=%s and msg_id=%s already exists (ID: %s). Skipping creation and push.",
                    source,
                    msg_id,
                    existing.id,
                )
                return existing.id, False

        marker_summary = build_marker_summary(summary, text, max_len=120)
        normalized_address = sanitize_address_candidate(address) or address

        # Determine city
        city = _determine_city(lat, lng, source, channel)

        duplicate = _find_duplicate_report(
            db,
            marker_summary or text,
            normalized_address,
            lat,
            lng,
            category,
            city=city,
        )
        final_desc = (description or summary or text or "")[:1500]
        photo_urls: list[str] = []

        # Для дубликатов не тратим LLM-вызов на генерацию изображения и не
        # перезаписываем описание дубликата новым URL — генерируем только для новых.
        if not duplicate:
            has_photo = bool(re.search(r"(https?://[^\s\]\n]+|/(?:static|media|uploads)/[^\s\]\n]+)", final_desc))
            if not has_photo:
                try:
                    import urllib.parse
                    from services.ai.zai_service import generate_text_using_llm

                    llm_prompt = (
                        f"Create a short, detailed, realistic image generation prompt in English for the following city issue.\n"
                        f"Category: {category}\n"
                        f"Description: {summary or text or final_desc}\n"
                        f"Output ONLY the prompt, up to 15-20 words, descriptive and clear. No quotes, no intro, no punctuation at the end. "
                        f"Always include terms like 'highly detailed, realistic photo, daytime'."
                    )
                    image_prompt_raw = await generate_text_using_llm(
                        user_prompt=llm_prompt,
                        system_prompt="You are an expert at writing prompts for realistic photo generation.",
                        max_tokens=60,
                        temperature=0.7
                    )
                    if image_prompt_raw:
                        image_prompt = image_prompt_raw.strip().strip('"').strip("'")
                    else:
                        image_prompt = f"realistic photo of {category} issue in a city, detailed"

                    encoded_prompt = urllib.parse.quote(image_prompt)
                    pollinations_url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=800&height=600&nologo=true&private=true"
                    photo_urls.append(pollinations_url)
                except Exception as e:
                    logger.warning(f"Failed to generate original photo for complaint: {e}")

        if duplicate:
            changed = False
            short_title = (marker_summary or summary or text or "")[:200]
            if short_title and duplicate.title != short_title:
                duplicate.title = short_title
                changed = True
            if final_desc and duplicate.description != final_desc:
                duplicate.description = final_desc
                changed = True
            if normalized_address and duplicate.address != normalized_address:
                duplicate.address = normalized_address
                changed = True
            if lat is not None and duplicate.lat is None:
                duplicate.lat = lat
                changed = True
            if lng is not None and duplicate.lng is None:
                duplicate.lng = lng
                changed = True
            if changed:
                db.commit()
            logger.info(
                "Duplicate complaint merged into report %s for %s @ %s (city: %s)",
                duplicate.id,
                category,
                normalized_address or f"{lat},{lng}",
                city,
            )
            return duplicate.id, False

        # Parse created_at if it's a string
        if created_at:
            if isinstance(created_at, str):
                try:
                    # Replace timezone 'Z' or other offset format if present
                    clean_dt = created_at.replace("Z", "+00:00")
                    created_at = datetime.fromisoformat(clean_dt)
                except Exception as parse_err:
                    logger.warning(f"Failed to parse created_at string '{created_at}': {parse_err}")
                    created_at = None

            if created_at and hasattr(created_at, "tzinfo") and created_at.tzinfo is not None:
                from datetime import UTC
                created_at = created_at.astimezone(UTC).replace(tzinfo=None)

        # Resolve UK by address
        uk_name = None
        uk_email = None
        try:
            from services.business.uk_service import find_uk_by_address
            if normalized_address:
                uk_res = find_uk_by_address(normalized_address)
                if uk_res:
                    uk_name = uk_res.get("name") or uk_res.get("full_name")
                    uk_email = uk_res.get("email")
        except Exception as uk_err:
            logger.debug(f"UK resolution error: {uk_err}")

        if not uk_name:
            if category in ["Дороги", "Транспорт", "Освещение", "Безопасность", "Экология"]:
                uk_name = "МБУ «Управление по дорожному хозяйству и благоустройству г. Нижневартовска»"
                uk_email = "udh_nv@mail.ru"
            else:
                uk_name = "Департамент ЖКХ Администрации г. Нижневартовска"
                uk_email = "dgkh@n-vartovsk.ru"

        report = Report(
            title=(marker_summary or summary or text or "")[:200],
            description=final_desc,
            lat=lat,
            lng=lng,
            address=normalized_address,
            category=category,
            status="open",
            source=source,
            telegram_message_id=str(msg_id) if msg_id else None,
            telegram_channel=channel,
            city=city,
            uk_name=uk_name,
            uk_email=uk_email,
            photo_urls=photo_urls or None,
            created_at=created_at or datetime.utcnow(),
        )
        db.add(report)
        db.commit()
        return report.id, True
    except Exception as e:
        logger.error(f"DB error: {e}")
        return None, False
    finally:
        if db is not None:
            db.close()
