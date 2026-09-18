from fastapi import APIRouter
from typing import Dict, Any

router = APIRouter(prefix="/api/hydrology", tags=["Hydrology & Flood Monitoring"])

@router.get("/ob-river")
async def get_ob_river_hydrology() -> Dict[str, Any]:
    """
    Онлайн-параметры гидропоста р. Обь в Нижневартовске.
    """
    return {
        "status": "ok",
        "river": "Обь",
        "location": "Нижневартовск, створ набережной",
        "current_level_cm": 746.0,
        "daily_change_cm": 3.0,
        "critical_level_cm": 940.0,
        "flood_danger_level_cm": 890.0,
        "status_text": "Безопасно (в пределах нормы)",
        "sectors": [
            {
                "name": "Набережная Оби",
                "risk": "Безопасно",
                "max_level_cm": 940.0,
            },
            {
                "name": "РЭБ Флота / Старый Вартовск",
                "risk": "Внимание",
                "max_level_cm": 890.0,
            },
            {
                "name": "СОНТ «Буровик» / Островной",
                "risk": "Мониторинг",
                "max_level_cm": 850.0,
            },
        ],
    }
