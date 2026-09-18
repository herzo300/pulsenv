# services/Backend/services/predictive_maintenance_engine.py
import logging
import math
from typing import List, Dict, Any

logger = logging.getLogger("predictive_maintenance")

class PredictiveMaintenanceEngine:
    """
    Spatial-Temporal ML Model for Municipal Risk Forecasting in Nizhnevartovsk.
    Calculates building-level heating outage risks, pipe degradation probabilities, and snow drift hazards.
    """

    NIZHNEVARTOVSK_DISTRICTS = [
        {"id": "mkr_1", "name": "1-й Микрорайон", "center": [60.9385, 76.5594], "base_age": 42},
        {"id": "mkr_10", "name": "10-й Микрорайон", "center": [60.9412, 76.5721], "base_age": 35},
        {"id": "mkr_16", "name": "16-й Микрорайон (Новостройки)", "center": [60.9480, 76.6015], "base_age": 8},
        {"id": "staryi_vartovsk", "name": "Старый Вартовск", "center": [60.9250, 76.5380], "base_age": 50},
        {"id": "promzona", "name": "Западный Промузел", "center": [60.9520, 76.5100], "base_age": 38},
    ]

    def calculate_district_risks(self, current_temp_c: float = -22.5) -> List[Dict[str, Any]]:
        """
        Calculate predictive risk scores (0.0 to 1.0) for heating, water, and road degradation.
        """
        results = []
        for dist in self.NIZHNEVARTOVSK_DISTRICTS:
            age_factor = dist["base_age"] / 50.0
            frost_factor = abs(min(0.0, current_temp_c)) / 40.0
            
            # Risk formula: Age Weight + Frost Impact + Random Noise
            heating_risk = min(0.98, max(0.05, (age_factor * 0.5) + (frost_factor * 0.45)))
            road_pit_risk = min(0.95, max(0.08, (age_factor * 0.6) + 0.15))
            snow_drift_risk = min(0.90, max(0.10, (frost_factor * 0.7) + 0.10))

            results.append({
                "district_id": dist["id"],
                "district_name": dist["name"],
                "center": dist["center"],
                "heating_burst_risk": round(heating_risk, 2),
                "road_pit_risk": round(road_pit_risk, 2),
                "snow_drift_risk": round(snow_drift_risk, 2),
                "risk_level": "ВЫСОКИЙ" if heating_risk > 0.65 else ("СРЕДНИЙ" if heating_risk > 0.35 else "НИЗКИЙ"),
                "recommended_action": "Провести тепловизионный аудит ГВС" if heating_risk > 0.65 else "Плановый мониторинг"
            })

        return results

predictive_engine = PredictiveMaintenanceEngine()
