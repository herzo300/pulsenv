"""
Strict Budget Controller & Rate Limiter for Camera AI Analysis.
Guarantees that total API costs for camera analysis NEVER exceed 1,000 RUB per month (33.33 RUB/day).
Automatically enforces 100% Free-Tier & Local YOLO fallback mode when budget thresholds are reached.
"""

from __future__ import annotations

import json
import logging
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict

logger = logging.getLogger(__name__)

ROOT = Path(__file__).resolve().parent.parent
LEDGER_FILE = ROOT / "data" / "camera_budget_ledger.json"
LEDGER_FILE.parent.mkdir(parents=True, exist_ok=True)

# Strict Budget Caps
MONTHLY_CAP_RUB = 1000.0  # Hard Monthly Cap: 1000 RUB
DAILY_CAP_RUB = 33.33     # Hard Daily Cap: ~33.33 RUB
USD_TO_RUB_RATE = 90.5

_lock = threading.RLock()


def _get_current_month_key() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m")


def _get_current_day_key() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _load_ledger() -> Dict[str, Any]:
    if not LEDGER_FILE.exists():
        return {"monthly": {}, "daily": {}}
    try:
        return json.loads(LEDGER_FILE.read_text(encoding="utf-8"))
    except Exception as e:
        logger.error("Error reading camera budget ledger: %s", e)
        return {"monthly": {}, "daily": {}}


def _save_ledger(data: Dict[str, Any]) -> None:
    try:
        LEDGER_FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    except Exception as e:
        logger.error("Error saving camera budget ledger: %s", e)


def can_spend_paid_api(estimated_cost_usd: float = 0.00012) -> bool:
    """
    Check if a paid VLM API call is allowed within the 1000 RUB/month hard cap budget.
    Returns False if budget cap reached, triggering mandatory 100% Free-Tier fallback.
    """
    with _lock:
        ledger = _load_ledger()
        month_key = _get_current_month_key()
        day_key = _get_current_day_key()

        month_spent_usd = float(ledger.get("monthly", {}).get(month_key, 0.0))
        day_spent_usd = float(ledger.get("daily", {}).get(day_key, 0.0))

        month_spent_rub = month_spent_usd * USD_TO_RUB_RATE
        day_spent_rub = day_spent_usd * USD_TO_RUB_RATE

        estimated_cost_rub = estimated_cost_usd * USD_TO_RUB_RATE

        # Check hard caps
        if (month_spent_rub + estimated_cost_rub) > MONTHLY_CAP_RUB:
            logger.warning(
                "🔒 HARD BUDGET CAP HIT: Monthly spending (%.2f RUB) + req (%.4f RUB) exceeds %.2f RUB. Enforcing Free-Tier Mode!",
                month_spent_rub, estimated_cost_rub, MONTHLY_CAP_RUB
            )
            return False

        if (day_spent_rub + estimated_cost_rub) > DAILY_CAP_RUB:
            logger.warning(
                "🔒 DAILY BUDGET CAP HIT: Daily spending (%.2f RUB) + req (%.4f RUB) exceeds %.2f RUB. Enforcing Free-Tier Mode!",
                day_spent_rub, estimated_cost_rub, DAILY_CAP_RUB
            )
            return False

        return True


def record_paid_spending(cost_usd: float) -> float:
    """Record a paid VLM API call cost in the ledger."""
    with _lock:
        ledger = _load_ledger()
        month_key = _get_current_month_key()
        day_key = _get_current_day_key()

        monthly = ledger.setdefault("monthly", {})
        daily = ledger.setdefault("daily", {})

        monthly[month_key] = round(float(monthly.get(month_key, 0.0)) + cost_usd, 6)
        daily[day_key] = round(float(daily.get(day_key, 0.0)) + cost_usd, 6)

        _save_ledger(ledger)
        return float(monthly[month_key]) * USD_TO_RUB_RATE


def get_budget_status() -> Dict[str, Any]:
    """Get current monthly & daily camera analysis budget status."""
    with _lock:
        ledger = _load_ledger()
        month_key = _get_current_month_key()
        day_key = _get_current_day_key()

        month_spent_usd = float(ledger.get("monthly", {}).get(month_key, 0.0))
        day_spent_usd = float(ledger.get("daily", {}).get(day_key, 0.0))

        month_spent_rub = round(month_spent_usd * USD_TO_RUB_RATE, 2)
        day_spent_rub = round(day_spent_usd * USD_TO_RUB_RATE, 2)

        return {
            "hard_monthly_cap_rub": MONTHLY_CAP_RUB,
            "hard_daily_cap_rub": DAILY_CAP_RUB,
            "current_month": month_key,
            "month_spent_rub": month_spent_rub,
            "month_spent_usd": round(month_spent_usd, 4),
            "month_remaining_rub": round(max(0.0, MONTHLY_CAP_RUB - month_spent_rub), 2),
            "current_day": day_key,
            "day_spent_rub": day_spent_rub,
            "day_spent_usd": round(day_spent_usd, 4),
            "day_remaining_rub": round(max(0.0, DAILY_CAP_RUB - day_spent_rub), 2),
            "budget_protection_active": True,
            "mode": "free_tier_fallback" if month_spent_rub >= MONTHLY_CAP_RUB or day_spent_rub >= DAILY_CAP_RUB else "normal_hybrid",
        }
