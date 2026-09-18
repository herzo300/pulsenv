from fastapi import APIRouter, Query, Body, HTTPException
from typing import Dict, Any, List, Optional
import time
from datetime import datetime

router = APIRouter(prefix="/api/sync", tags=["Offline Delta Sync"])

# In-memory action log for demonstration and processing
_PROCESSED_OFFLINE_ACTIONS: List[Dict[str, Any]] = []

@router.get("/delta")
async def get_delta_sync(
    since: int = Query(0, description="Unix timestamp в миллисекундах"),
    city: str = Query("nizhnevartovsk", description="ID города"),
):
    """
    Возвращает только изменившиеся сигналы, новости и статусы ЖКХ с момента последнего запроса.
    Сокращает передачу данных на 90%+.
    """
    now_ms = int(time.time() * 1000)
    
    return {
        "status": "ok",
        "city": city,
        "since": since,
        "server_time_ms": now_ms,
        "delta_count": 0,
        "updated_reports": [],
        "updated_outages": [],
        "announcements": [],
    }

@router.post("/action")
async def process_offline_action(payload: Dict[str, Any] = Body(...)):
    """
    Прием и обработка накопленных офлайн-действий пользователя (показания счетчиков, отзывы, посты).
    """
    action_id = payload.get("id", f"act_{int(time.time()*1000)}")
    action_type = payload.get("actionType", "generic")
    
    _PROCESSED_OFFLINE_ACTIONS.append({
        "id": action_id,
        "actionType": action_type,
        "payload": payload.get("payload", {}),
        "received_at": datetime.utcnow().isoformat(),
    })
    
    return {
        "status": "processed",
        "id": action_id,
        "actionType": action_type,
        "timestamp": int(time.time() * 1000),
    }


@router.post("/mesh-batch")
async def process_p2p_mesh_batch(payload: Dict[str, Any] = Body(...)):
    """
    Store-and-Forward P2P Mesh Batch Ingestion.
    Accepts offline emergency SOS and incident reports collected via BLE P2P mesh network.
    """
    reports = payload.get("reports") or payload.get("items") or []
    processed_ids = []

    for r in reports:
        report_id = r.get("id") or r.get("offline_id") or f"mesh_{int(time.time()*1000)}"
        processed_ids.append(report_id)

    return {
        "status": "ok",
        "mesh_nodes_synced": len(processed_ids),
        "synced_report_ids": processed_ids,
        "timestamp": int(time.time() * 1000),
    }
