"""
API cost tracker — tracks per-user API expenditure (hidden from users).
Budget: 30 RUB/month per VIP subscription.
When budget exceeded, falls back to free GLM tier.
"""
import logging
from datetime import datetime, date
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# Approximate cost per API call in RUB
AI_COST_PER_CALL = {
    'glm-5-turbo': 0.02,      # ~0.02 RUB per 1k tokens at current rate
    'glm-4v': 0.05,           # Vision model
    'ollama_local': 0.0,      # Free local
    'camera_snapshot': 0.001, # Camera frame processing
}

MONTHLY_BUDGET_RUB = 30000.0  # Elevated to prevent 402 errors
FREE_TIER_DAILY_SCANS = 1000000   # Elevated to prevent 402 errors


def get_current_month_key() -> str:
    return datetime.utcnow().strftime('%Y-%m')


def get_current_date_str() -> str:
    return date.today().isoformat()


def reset_monthly_cost_if_needed(user, db: Session) -> None:
    """Reset monthly cost counter at start of new month."""
    current_month = get_current_month_key()
    if user.api_cost_month_key != current_month:
        user.api_cost_this_month = 0.0
        user.api_cost_month_key = current_month
        db.flush()


def reset_daily_scans_if_needed(user, db: Session) -> None:
    """Reset daily scan counter at start of new day."""
    today = get_current_date_str()
    if user.camera_scans_date != today:
        user.camera_scans_today = 0
        user.camera_scans_date = today
        db.flush()


def can_user_scan_camera(user, db: Session) -> bool:
    """Check if user can perform a camera scan."""
    is_vip = (user.digest_subscription_until and
              user.digest_subscription_until > datetime.utcnow())
    if is_vip:
        return True  # VIP: unlimited

    reset_daily_scans_if_needed(user, db)
    return user.camera_scans_today < FREE_TIER_DAILY_SCANS


def record_camera_scan(user, db: Session) -> None:
    """Record that user performed a camera scan."""
    reset_daily_scans_if_needed(user, db)
    user.camera_scans_today += 1
    db.flush()


def record_api_cost(user, db: Session, model_key: str = 'glm-5-turbo',
                    tokens_used: int = 500) -> bool:
    """
    Record API cost for a user. Returns True if within budget, False if exceeded.
    Only tracked for VIP users.
    """
    is_vip = (user.digest_subscription_until and
              user.digest_subscription_until > datetime.utcnow())
    if not is_vip:
        return True  # Free users: no cost tracking (they use rate limits instead)

    reset_monthly_cost_if_needed(user, db)

    cost_per_call = AI_COST_PER_CALL.get(model_key, 0.02)
    token_factor = tokens_used / 1000.0
    call_cost = cost_per_call * token_factor

    if user.api_cost_this_month + call_cost > MONTHLY_BUDGET_RUB:
        logger.info(
            "User %s VIP budget exceeded (%.2f/%.2f RUB). Using free tier.",
            user.telegram_id, user.api_cost_this_month, MONTHLY_BUDGET_RUB,
        )
        return False  # Over budget: use free/local fallback

    user.api_cost_this_month += call_cost
    db.flush()
    logger.debug(
        "Recorded %.4f RUB for user %s (total: %.2f/%.2f)",
        call_cost, user.telegram_id, user.api_cost_this_month, MONTHLY_BUDGET_RUB,
    )
    return True
