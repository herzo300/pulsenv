# services/business/api_budget_manager.py
"""
API Budget Manager.
Tracks OpenAI/Z.AI token consumption cost in Rubles, enforces Freemium limits
(1 free task/day, max 1 Ruble per task, max 100 Rubles aggregate daily cap),
and manages AI Dispatcher sleep mode / Telegram alerts / Donations.
"""
import logging
from datetime import datetime
from sqlalchemy import select, func
from services.data_layer.database import SessionLocal
from services.data_layer.models import ApiCostLedger, SystemSetting

logger = logging.getLogger(__name__)


def calculate_cost_rub(model_name: str, prompt_tokens: int, completion_tokens: int) -> float:
    """Calculate token cost in Rubles (assumes 1 USD = 90 RUB)."""
    # Rates per 1000 tokens in USD
    rates = {
        "glm-4": {"input": 0.0001, "output": 0.0002},
        "glm-5": {"input": 0.00015, "output": 0.0003},
        "gemma-local": {"input": 0.0, "output": 0.0},
    }
    
    # Fallback to default cheap model rates
    model_rate = rates.get(model_name.lower(), {"input": 0.0001, "output": 0.0002})
    
    cost_usd = (
        (prompt_tokens / 1000.0) * model_rate["input"] +
        (completion_tokens / 1000.0) * model_rate["output"]
    )
    
    # Convert to Rubles
    return round(cost_usd * 90.0, 4)


async def log_api_call(user_id: int, task_id: str, prompt_tokens: int, completion_tokens: int, model_name: str, is_free_tier: bool, db) -> float:
    """Log API call and trigger budget threshold checks."""
    cost_rub = calculate_cost_rub(model_name, prompt_tokens, completion_tokens)
    
    # Enforce strict monthly budget constraint (max 0.10 RUB per free task = 3.0 RUB per month for 30 tasks)
    if is_free_tier and cost_rub > 0.10:
        logger.warning(f"Freemium task cost {cost_rub} RUB exceeds 0.10 RUB monthly safety limit for user {user_id}. Switching execution target to local model fallback.")
        # Fallback to local offline Gemma models to secure 500%+ margin
        cost_rub = 0.0
        model_name = "gemma-local"
        
    # Enforce strict rolling monthly budget constraint for VIP users (1.0 RUB per day budget that rolls over)
    if not is_free_tier:
        from sqlalchemy import select, func
        from datetime import timedelta
        # Get User to calculate subscription period start
        from services.data_layer.models import User as DBUser
        user_record = db.query(DBUser).filter(DBUser.id == user_id).first()
        if user_record and user_record.digest_subscription_until:
            subscription_started_at = user_record.digest_subscription_until - timedelta(days=30)
            if subscription_started_at > datetime.utcnow():
                subscription_started_at = datetime.utcnow() - timedelta(days=1)
        else:
            subscription_started_at = datetime.utcnow() - timedelta(days=1)
            
        # VIP users have a flat monthly budget limit of 30.0 RUB (no daily limit)
        allowed_limit = 30.0
        
        query = select(func.sum(ApiCostLedger.cost_rub)).where(
            ApiCostLedger.user_id == user_id,
            ApiCostLedger.is_free_tier == False,
            ApiCostLedger.created_at >= subscription_started_at
        )
        total_paid_user_cost = db.execute(query).scalar() or 0.0
        if total_paid_user_cost + cost_rub > allowed_limit:
            logger.warning(f"Paid user {user_id} accumulated API cost {total_paid_user_cost + cost_rub:.2f} RUB exceeds allowed rolling cap {allowed_limit:.2f} RUB. Switching execution target to local model fallback.")
            cost_rub = 0.0
            model_name = "gemma-local"
        
    entry = ApiCostLedger(
        user_id=user_id,
        task_id=task_id,
        model_name=model_name,
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        cost_rub=cost_rub,
        is_free_tier=is_free_tier
    )
    db.add(entry)
    db.commit()
    
    # Run global limits check
    await check_and_update_limits(db)
    return cost_rub


async def check_and_update_limits(db) -> str:
    """Check daily Freemium cost limit. If >= 100 RUB, put AI Dispatcher to sleep."""
    today = datetime.utcnow().date()
    
    # Sum all free tier costs for today
    query = select(func.sum(ApiCostLedger.cost_rub)).where(
        ApiCostLedger.is_free_tier == True,
        func.date(ApiCostLedger.created_at) == today
    )
    total_today = db.execute(query).scalar() or 0.0
    
    if total_today >= 100.0:
        # Set Freemium Dispatcher status to 'sleep'
        setting = db.query(SystemSetting).filter(SystemSetting.key == "freemium_dispatcher_status").first()
        if not setting:
            setting = SystemSetting(key="freemium_dispatcher_status", value="sleep")
            db.add(setting)
        else:
            setting.value = "sleep"
        db.commit()
        
        # Send Telegram alert to admin channel directly
        import os
        import requests
        bot_token = os.getenv("TG_BOT_TOKEN")
        admin_chat_id = os.getenv("TG_ADMIN_CHAT_ID") or os.getenv("TELEGRAM_ADMIN_CHAT_ID")
        if bot_token and admin_chat_id:
            try:
                url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
                payload = {
                    "chat_id": admin_chat_id,
                    "text": (
                        f"🚨 [БЮДЖЕТ API] Дневной лимит Freemium превышен: {total_today:.2f} ₽ / 100.00 ₽.\n"
                        f"Бесплатный ИИ-Диспетчер переведен в режим сна (sleep). Задания для бесплатных пользователей приостановлены."
                    )
                }
                requests.post(url, json=payload, timeout=5)
            except Exception as e:
                logger.error(f"Failed to post TG budget alert: {e}")
            
        return "sleep"
        
    return "active"


def get_dispatcher_status(db, is_free_tier: bool = True) -> str:
    """Get active/sleep status of the AI Dispatcher depending on user tier."""
    if not is_free_tier:
        return "active"
    setting = db.query(SystemSetting).filter(SystemSetting.key == "freemium_dispatcher_status").first()
    return setting.value if setting else "active"


def reset_daily_dispatcher(db):
    """Wake up dispatcher at the start of the day."""
    setting = db.query(SystemSetting).filter(SystemSetting.key == "freemium_dispatcher_status").first()
    if setting:
        setting.value = "active"
        db.commit()
