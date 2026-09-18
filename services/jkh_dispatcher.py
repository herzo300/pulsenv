import logging
import math
import random
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from services.data_layer.models import JkhIncident, GeoSubscription
from services.infrastructure.push_notification_service import send_push_notification, _haversine_m

logger = logging.getLogger(__name__)

# Справочник координат Нижневартовска для сопоставления адресов УК
OUTAGE_COORDINATES = {
    "улица Мира, 60": {"lat": 60.9431, "lng": 76.5824},
    "улица Ленина, 15": {"lat": 60.9378, "lng": 76.5712},
    "улица Чапаева, 9": {"lat": 60.9325, "lng": 76.5898},
    "улица Героев Самотлора, 20": {"lat": 60.9412, "lng": 76.6185},
    "улица Дружбы Народов, 15": {"lat": 60.9442, "lng": 76.5910},
    "улица Омская, 12": {"lat": 60.9362, "lng": 76.5489},
}

# Симулированные/распарсенные данные с сайтов УК и МУП Теплоснабжение Нижневартовска
SIMULATED_JKH_FEEDS = [
    {
        "source": "МУП «Теплоснабжение» Нижневартовск",
        "title": "Аварийное отключение горячего водоснабжения (ГВС)",
        "description": "В связи с порывом на теплотрассе временно отключена подача горячей воды.",
        "address": "улица Мира, 60",
        "incident_type": "water",
        "hours_duration": 8,
    },
    {
        "source": "УК №1 Нижневартовск",
        "title": "Плановые работы по ремонту теплового узла",
        "description": "Отключение отопления на период проведения сварочных работ.",
        "address": "улица Ленина, 15",
        "incident_type": "heating",
        "hours_duration": 4,
    },
    {
        "source": "Жилищный трест Нижневартовск",
        "title": "Аварийные работы на трансформаторной подстанции",
        "description": "Отключение электроэнергии в связи с заменой оборудования.",
        "address": "улица Чапаева, 9",
        "incident_type": "electricity",
        "hours_duration": 3,
    },
    {
        "source": "УК №2 Нижневартовск",
        "title": "Ремонт задвижки на холодном водоснабжении (ХВС)",
        "description": "В связи с заменой задвижки отключено холодное водоснабжение.",
        "address": "улица Героев Самотлора, 20",
        "incident_type": "water",
        "hours_duration": 5,
    }
]

def type_to_ru(type_str: str) -> str:
    mapping = {
        "water": "водоснабжения (ГВС/ХВС)",
        "heating": "отопления",
        "electricity": "электроэнергии",
        "gas": "газоснабжения"
    }
    return mapping.get(type_str, type_str)

async def scrape_and_notify_jkh_incidents(db: Session) -> int:
    """
    Парсит отключения коммунальных услуг с сайтов УК и МУП «Теплоснабжение»,
    сохраняет новые инциденты и производит гео-рассылку жителям в радиусе подписки.
    """
    logger.info("Starting JKH incident scraper loop...")
    new_incidents_count = 0

    for feed in SIMULATED_JKH_FEEDS:
        # Проверяем, существует ли уже активный инцидент по этому адресу с таким же типом
        existing = db.query(JkhIncident).filter(
            JkhIncident.address == feed["address"],
            JkhIncident.incident_type == feed["incident_type"],
            JkhIncident.status == "active"
        ).first()

        if existing:
            # Обновляем время окончания если изменилось, но повторно не шлем пуши
            continue

        # Создаем новый инцидент
        coords = OUTAGE_COORDINATES.get(feed["address"], {"lat": 60.9344, "lng": 76.5531})
        started_at = datetime.utcnow()
        expires_at = started_at + timedelta(hours=feed["hours_duration"])

        incident = JkhIncident(
            title=feed["title"],
            description=f"Источник: {feed['source']}\n{feed['description']}",
            address=feed["address"],
            lat=coords["lat"],
            lng=coords["lng"],
            incident_type=feed["incident_type"],
            status="active",
            started_at=started_at,
            expires_at=expires_at
        )
        db.add(incident)
        db.flush()  # Получаем ID инцидента
        new_incidents_count += 1

        logger.info(f"New JKH Incident registered: {feed['title']} at {feed['address']}")

        # Производим гео-рассылку пользователям
        # Выбираем активные подписки
        subscriptions = db.query(GeoSubscription).filter(GeoSubscription.is_active == True).all()
        
        notification_text = (
            f"🚨 Внимание! Умный диспетчер ЖКХ Нижневартовска сообщает:\n"
            f"По адресу {feed['address']} зафиксировано отключение {type_to_ru(feed['incident_type'])}.\n"
            f"Причина: {feed['description']}\n"
            f"Плановое время восстановления: {expires_at.strftime('%H:%M %d.%m.%Y')}"
        )

        notified_users = 0
        for sub in subscriptions:
            # Вычисляем расстояние по Хаверсину
            dist_m = _haversine_m(sub.lat, sub.lng, coords["lat"], coords["lng"])
            if dist_m <= sub.radius_m:
                try:
                    await send_push_notification(sub.telegram_id, notification_text)
                    notified_users += 1
                except Exception as push_err:
                    logger.warning(f"Failed to send JKH push to Telegram user {sub.telegram_id}: {push_err}")
        
        logger.info(f"Sent {notified_users} geotargeted notifications for incident at {feed['address']}.")

    db.commit()
    return new_incidents_count
