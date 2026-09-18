"""Telegram message handler."""

import logging

from .config import MIN_TEXT_LENGTH
from .filters import is_ad_or_spam, is_relevant_message
from .pipeline import process_complaint, stats

logger = logging.getLogger(__name__)

# RealtimeGuard — initialized in main()
guard = None


async def handle_telegram_message(client, event):
    """Обработчик новых сообщений из TG каналов (текст + фото)"""
    try:
        # RealtimeGuard: проверка таймстемпа
        chat = event.chat or getattr(event.message, "chat", None)
        if guard:
            msg_time = event.message.date
            if not guard.is_new_message(msg_time):
                channel = getattr(chat, "username", "") or ""
                logger.info(
                    f"⏭️ Старое сообщение: @{channel}/{event.message.id}, время: {msg_time}"
                )
                return

            source = f"tg:{getattr(chat, 'username', '') or ''}"
            if guard.is_duplicate(source, event.message.id):
                logger.debug(f"⏭️ Дубликат: {source}/{event.message.id}")
                return

        text = event.message.text or event.message.message or ""
        channel_username = getattr(chat, "username", "") or "" if chat else ""
        channel_title = (getattr(chat, "title", "") or channel_username) if chat else channel_username
        message_id = event.message.id
        msg_link = f"https://t.me/{channel_username}/{message_id}"

        # Обработка фото с подписью
        photo_result = None
        uploaded_url = None
        if event.message.photo:
            import tempfile

            tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
            try:
                await client.download_media(event.message, file=tmp.name)
                tmp.close()
                caption = event.message.message or ""
                from services.zai_vision_service import analyze_image_with_glm4v

                photo_result = await analyze_image_with_glm4v(tmp.name, caption)

                # Upload the image to local storage
                try:
                    with open(tmp.name, "rb") as f:
                        img_bytes = f.read()
                    import time
                    from .local_media_storage import save_image
                    filename = f"tg_{int(time.time())}_{event.message.id}.jpg"
                    uploaded_url = save_image(img_bytes, filename)
                except Exception as upload_err:
                    logger.error(f"Failed to upload Telegram photo: {upload_err}")

                # text по‑прежнему нужен для базы и дальнейшей обработки,
                # но в служебный канал мы шлём только аналитическое summary,
                # поэтому НЕ дублируем сюда сырой текст.
                if not text:
                    text = caption or photo_result.get("description", "")
            except Exception as e:
                logger.error(f"Photo download/analysis error: {e}")
            finally:
                import os as _os

                try:
                    _os.unlink(tmp.name)
                except OSError:
                    pass

        if not text or len(text.strip()) < MIN_TEXT_LENGTH:
            return

        stats["tg_total"] += 1

        if is_ad_or_spam(text):
            stats["tg_filtered"] += 1
            return

        # Если есть результат анализа фото — используем его
        if photo_result:
            category = photo_result.get("category", "Прочее")
            address = photo_result.get("address")
            # В служебный канал отправляем только анализ (описание от модели),
            # без прямого копирования текста жалобы.
            raw_desc = photo_result.get("description")
            title = photo_result.get("title") or (f"ЧП: {category}" if category == "ЧП" else f"Сигнал: {category}")
            if raw_desc:
                summary = raw_desc
            else:
                summary = (
                    f"Проблема ({category}): требуется проверка по фото из канала."
                )
            provider = photo_result.get("provider", "?")
            location_hints = photo_result.get("location_hints")
            exif_lat = photo_result.get("exif_lat")
            exif_lon = photo_result.get("exif_lon")
            has_vehicle = photo_result.get("has_vehicle_violation", False)
            plates = photo_result.get("plates")

            if has_vehicle and plates:
                summary = f"🚗 Нарушение парковки ({plates}). {summary}"
            elif has_vehicle:
                summary = f"🚗 Нарушение парковки. {summary}"

            if uploaded_url:
                summary = f"{summary}\nФото: {uploaded_url}"
        else:
            # Текстовый анализ
            from services.zai_service import analyze_complaint

            analysis = await analyze_complaint(text)
            category = analysis.get("category", "Прочее")
            address = analysis.get("address")
            title = analysis.get("title") or analysis.get("summary", text[:40])
            summary = analysis.get("description") or analysis.get("summary", text[:100])
            provider = analysis.get("provider", "?")
            location_hints = analysis.get("location_hints")
            exif_lat = None
            exif_lon = None

            # AI фильтрация
            if not analysis.get("relevant", True):
                stats["tg_filtered"] += 1
                logger.info(
                    f"⏭️ AI: нерелевантно [{provider}] из @{channel_username}: {text[:40]}..."
                )
                return

        if not is_relevant_message(text, category):
            stats["tg_filtered"] += 1
            return

        # Если есть EXIF координаты — передаём их напрямую в process_complaint
        published = await process_complaint(
            client,
            text,
            category,
            address,
            summary,
            provider,
            source=f"tg:@{channel_username}",
            source_label=f"@{channel_username}",
            source_link=msg_link,
            msg_id=message_id,
            channel=f"@{channel_username}",
            location_hints=location_hints,
            exif_lat=exif_lat,
            exif_lon=exif_lon,
            title=title,
            created_at=event.message.date,
        )
        if published:
            stats["tg_published"] += 1
            logger.info(
                f"✅ TG [{provider}] {category} из @{channel_username} (Городская проблема)"
            )

        # RealtimeGuard: отмечаем как обработанное
        if guard:
            guard.mark_processed(f"tg:{channel_username}", message_id)

    except Exception as e:
        logger.error(f"❌ TG handler error: {e}", exc_info=True)
