# services/business/agent_scheduler.py
import logging
from datetime import datetime
from sqlalchemy.orm import Session
from services.data_layer.models import AgentTask, NewsTopicSubscription, User
from services.ai.rag_city_assistant import ask_city_question

logger = logging.getLogger(__name__)

async def process_scheduled_tasks(db: Session) -> int:
    """Find and execute pending agent tasks whose scheduled_for time has passed."""
    now = datetime.utcnow()
    # Prioritize scheduled tasks from VIP users with active subscriptions first
    tasks = db.query(AgentTask).join(User, AgentTask.user_id == User.id).filter(
        AgentTask.status == "pending",
        AgentTask.scheduled_for <= now
    ).order_by(
        User.digest_subscription_until.desc().nullslast(),
        AgentTask.scheduled_for.asc()
    ).all()
    
    processed = 0
    for task in tasks:
        logger.info(f"Executing scheduled agent task #{task.id} for user #{task.user_id}...")
        task.status = "running"
        db.commit()
        
        try:
            # Run the agent task using our robust RAG assistant
            res = await ask_city_question(task.task_description)
            task.result_report = res.get("answer", "Не удалось получить ответ от ИИ.")
            task.status = "completed"
            task.is_notified = True
            db.commit()
            processed += 1
            logger.info(f"Scheduled task #{task.id} completed successfully.")
            
            # Here we would invoke a Telegram bot push notification to the user
            # e.g., await bot.send_message(user.telegram_id, f"Ваш запланированный отчет готов:\n{task.result_report}")
            
        except Exception as e:
            logger.error(f"Failed to execute task #{task.id}: {e}")
            task.status = "failed"
            task.result_report = f"Ошибка выполнения: {e}"
            db.commit()
            
    return processed


def process_news_alerts(db: Session, post_title: str, post_text: str) -> list[dict]:
    """Check if a new news post matches user keyword topic subscriptions and trigger alerts."""
    full_text = f"{post_title} {post_text}".lower()
    active_subs = db.query(NewsTopicSubscription).filter(
        NewsTopicSubscription.is_active == True
    ).all()
    
    triggered_alerts = []
    for sub in active_subs:
        keyword = sub.topic_keyword.lower()
        if keyword in full_text:
            user = db.query(User).filter(User.id == sub.user_id).first()
            user_label = user.username or f"User_{user.id}"
            
            alert = {
                "user_id": sub.user_id,
                "username": user_label,
                "matched_keyword": sub.topic_keyword,
                "post_title": post_title,
                "alert_text": f"🔔 Уведомление по подписке '{sub.topic_keyword}': Обнаружена новость '{post_title}'!"
            }
            triggered_alerts.append(alert)
            logger.info(f"Triggered alert for user {user_label} on topic '{sub.topic_keyword}'")
            
    return triggered_alerts
