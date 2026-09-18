# services/Backend/routers/predictive_maintenance.py
import logging
from typing import Dict, Any, List
from fastapi import APIRouter, Query
try:
    from services.Backend.services.predictive_maintenance_engine import predictive_engine
except ImportError:
    from services.predictive_maintenance_engine import predictive_engine

logger = logging.getLogger("predictive_router")
router = APIRouter(prefix="/api/v1/predictive", tags=["Predictive Maintenance ML Engine"])

@router.get("/risk-map")
async def get_predictive_risk_map(temp_c: float = Query(-22.5, description="Current ambient temperature in Celsius")):
    """
    Predictive Municipal Risk Map Endpoint.
    Returns calculated risk heat scores (heating bursts, road pits, snow drifts) per city district.
    """
    try:
        districts_risk = predictive_engine.calculate_district_risks(current_temp_c=temp_c)
        return {
            "city": "Нижневартовск",
            "ambient_temp_c": temp_c,
            "districts_count": len(districts_risk),
            "high_risk_count": sum(1 for d in districts_risk if d["risk_level"] == "ВЫСОКИЙ"),
            "districts": districts_risk
        }
    except Exception as e:
        logger.error(f"Error computing predictive risk map: {e}")
        return {"error": str(e), "districts": []}
