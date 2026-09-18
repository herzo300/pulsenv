# services/business/traffic_analyzer.py
import logging
from datetime import datetime, UTC
from sqlalchemy.orm import Session
from services.data_layer.models import Report
from services.Backend.routers.vlm import _capture_frame_from_url, describe_frame

logger = logging.getLogger(__name__)

# Coordinates and details of key road cameras in Nizhnevartovsk
TRAFFIC_CAMERAS = [
    {
        "id": "cam_chapaeva_lenina",
        "name": "Кольцо Чапаева — Ленина",
        "url": "https://nginx03.pride-net.ru/ln19/index.m3u8",
        "lat": 60.934623,
        "lng": 76.590366
    },
    {
        "id": "cam_chapaeva_60let",
        "name": "Перекресток Чапаева — 60 лет Октября",
        "url": "https://nginx01.pride-net.ru/per60l46/index.m3u8",
        "lat": 60.927771,
        "lng": 76.583049
    },
    {
        "id": "cam_60let_10",
        "name": "Улица 60 лет Октября, 10",
        "url": "https://stream3.dantser.org/NV_60Let_10/tracks-v1/mono.ts.m3u8",
        "lat": 60.928985,
        "lng": 76.557381
    },
    {
        "id": "cam_geroev_samotlora",
        "name": "Улица Героев Самотлора (в сторону Северной)",
        "url": "https://nginx01.pride-net.ru/cam_geroi28_1/index.m3u8",
        "lat": 60.937,
        "lng": 76.6305
    }
]

async def check_camera_jams(db: Session):
    """Scan city cameras, check for traffic jams via Vision LLM, and update map markers."""
    logger.info("Starting automated road traffic jam analysis via VLM...")
    
    for cam in TRAFFIC_CAMERAS:
        try:
            # 1. Capture live frame
            frame = _capture_frame_from_url(cam["url"])
            if not frame:
                logger.warning(f"Could not capture frame for traffic camera: {cam['name']}")
                continue
                
            # 2. Vision analysis prompt for traffic jams
            prompt = (
                "Ты — дорожный инспектор. Посмотри на кадр камеры перекрестка. "
                "Есть ли на этой дороге затор, сильная пробка или полностью заблокированное движение? "
                "Ответь строго одним словом: YES или NO."
            )
            
            description, _ = await describe_frame(frame, cam["name"], question=prompt)
            is_jammed = "YES" in description.upper()
            
            # Find existing traffic jam report for this camera in DB
            existing_report = db.query(Report).filter(
                Report.source == f"system:traffic:{cam['id']}"
            ).first()
            
            if is_jammed:
                if not existing_report:
                    # Create new traffic jam incident marker on map
                    jam_report = Report(
                        title="🔴 Дорожный затор (ИИ-Детектор)",
                        description=f"ИИ-система зафиксировала плотное движение и затор на перекрестке: {cam['name']}.",
                        category="Дороги",
                        address=cam["name"],
                        lat=cam["lat"],
                        lng=cam["lng"],
                        source=f"system:traffic:{cam['id']}",
                        status="open",
                        likes_count=1,
                        created_at=datetime.now(UTC).replace(tzinfo=None)
                    )
                    db.add(jam_report)
                    db.commit()
                    logger.info(f"Traffic jam marker CREATED for {cam['name']}")
            else:
                if existing_report:
                    # Remove traffic jam marker since it's cleared
                    db.delete(existing_report)
                    db.commit()
                    logger.info(f"Traffic jam marker REMOVED for {cam['name']}")
                    
        except Exception as e:
            logger.error(f"Error analyzing traffic for camera {cam['name']}: {e}")
            db.rollback()
