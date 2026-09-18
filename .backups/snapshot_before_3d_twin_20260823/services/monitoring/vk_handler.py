"""VK complaint handler."""

import logging

from .pipeline import process_complaint, stats

logger = logging.getLogger(__name__)


async def handle_vk_complaint(client, complaint_data: dict):
    """Callback для VK мониторинга — обрабатывает найденную жалобу"""
    stats["vk_total"] += 1

    photos = complaint_data.get("photos", [])
    uploaded_urls = []
    if photos:
        import httpx
        import time
        from .local_media_storage import save_image
        
        async with httpx.AsyncClient() as client_http:
            for idx, photo_url in enumerate(photos):
                try:
                    response = await client_http.get(photo_url, timeout=10.0)
                    if response.status_code == 200:
                        filename = f"vk_{int(time.time())}_{complaint_data.get('post_id', idx)}_{idx}.jpg"
                        local_url = save_image(response.content, filename)
                        if local_url:
                            uploaded_urls.append(local_url)
                except Exception as ex:
                    logger.error(f"Failed to download/save VK photo: {ex}")

    summary = complaint_data.get("summary") or ""
    if uploaded_urls:
        summary = f"{summary}\n" + "\n".join(f"Фото: {url}" for url in uploaded_urls)

    published = await process_complaint(
        client,
        text=complaint_data["text"],
        category=complaint_data["category"],
        address=complaint_data.get("address"),
        summary=summary,
        provider=complaint_data.get("provider", "?"),
        source=complaint_data["source"],
        source_label=complaint_data["source_name"],
        source_link=complaint_data["post_link"],
        msg_id=complaint_data.get("post_id"),
        location_hints=complaint_data.get("location_hints"),
        title=complaint_data.get("title"),
        created_at=complaint_data.get("post_date"),
    )
    if published:
        stats["vk_published"] += 1
        logger.info(
            f"✅ VK [{complaint_data.get('provider')}] {complaint_data['category']} из {complaint_data['source_name']}"
        )

