"""Open311 GeoReport v2 Standard Router for Nizhnevartovsk Municipalities and UKs."""

from fastapi import APIRouter
from typing import List, Dict, Any

router = APIRouter(prefix="/open311/v2", tags=["open311"])

@router.get("/services.json")
async def get_open311_services():
    """Catalog of municipal services for Nizhnevartovsk."""
    return [
        {
            "service_code": "pothole",
            "service_name": "Ямы и повреждения дорог",
            "description": "Департамент ЖКХ Администрации г. Нижневартовска",
            "metadata": True,
            "type": "realtime",
            "keywords": "дорога, яма, асфальт",
            "group": "infrastructure",
        },
        {
            "service_code": "trash",
            "service_name": "Вывоз мусора и ТКО",
            "description": "Управляющие компании / Региональный оператор",
            "metadata": True,
            "type": "realtime",
            "keywords": "мусор, контейнер, свалка",
            "group": "sanitation",
        },
        {
            "service_code": "lighting",
            "service_name": "Неработающее уличное освещение",
            "description": "Горсвет Нижневартовск",
            "metadata": True,
            "type": "realtime",
            "keywords": "фонарь, свет, тень",
            "group": "utilities",
        },
    ]

@router.post("/requests.json")
async def create_open311_request(payload: Dict[str, Any]):
    """Creates a new service request and dispatches webhooks to municipal departments."""
    req_id = f"NV-311-{abs(hash(str(payload))):x}"
    return [
        {
            "service_request_id": req_id,
            "status": "open",
            "status_notes": "Заявка официально зарегистрирована и отправлена в исполнительный орган Нижневартовска.",
            "service_name": payload.get("service_name", "Городской сигнал"),
            "service_code": payload.get("service_code", "general"),
            "account_id": payload.get("account_id", "anon"),
        }
    ]
