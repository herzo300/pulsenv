import asyncio
import logging
from datetime import UTC, datetime

from sqlalchemy import select

from services.data_layer.database import SessionLocal
from services.data_layer.models import VipSubscription
from services.push_notification_service import send_push_notification

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("AICreditManager")


class AICreditManager:
    async def run(self):
        """Main loop to deduct credits every 30 seconds for better precision."""
        while True:
            try:
                await self.deduct_credits()
            except Exception as e:
                logger.error(f"Error in credit deduction: {e}")
            await asyncio.sleep(30)

    async def deduct_credits(self):
        with SessionLocal() as session:
            # Find all active AI tracks
            stmt = select(VipSubscription).where(
                VipSubscription.is_track_active == True
            )
            active_subs = session.execute(stmt).scalars().all()

            for sub in active_subs:
                try:
                    now = datetime.now(UTC).replace(tzinfo=None)

                    if not sub.last_deduction_at:
                        sub.last_deduction_at = sub.track_started_at or now

                    # Calculate seconds elapsed for precision
                    delta = now - sub.last_deduction_at
                    seconds_elapsed = delta.total_seconds()

                    if seconds_elapsed >= 30:
                        # Convert to fractional minutes for internal storage if needed,
                        # or just keep it as integer for simpler display but deduct more frequently
                        minutes_to_deduct = seconds_elapsed / 60.0

                        sub.ai_minutes_used += (
                            int(minutes_to_deduct) if minutes_to_deduct >= 1 else 0
                        )
                        # Alternatively, we could store ai_minutes_used as a Float in the DB.
                        # But since it's Integer in models.py, we only deduct full minutes but update last_deduction_at.

                        # Optimization: only deduct if at least 1 minute passed OR keep track of partial minutes?
                        # Let's stick to 1-minute increments but check every 30s.

                        full_minutes = int(seconds_elapsed // 60)
                        if full_minutes >= 1:
                            sub.ai_minutes_used += full_minutes
                            sub.last_deduction_at = now
                            logger.info(
                                f"User {sub.telegram_id}: Deducted {full_minutes} min. Total used: {sub.ai_minutes_used}/{sub.ai_minutes_total}"
                            )

                        # Check if limits reached
                        if sub.ai_minutes_used >= sub.ai_minutes_total:
                            sub.is_track_active = False
                            logger.warning(
                                f"User {sub.telegram_id}: Credits exhausted. Stopping task."
                            )

                            # Notify user
                            msg = "⚠️ Ваше время AI-обработки закончилось. Задача остановлена. Пожалуйста, пополните баланс."
                            asyncio.create_task(
                                send_push_notification(sub.telegram_id, msg)
                            )
                except Exception as e:
                    logger.error(f"Error processing sub for {sub.telegram_id}: {e}")

            session.commit()


# Integration with tasks
async def start_tracking(telegram_id: int):
    with SessionLocal() as session:
        stmt = select(VipSubscription).where(VipSubscription.telegram_id == telegram_id)
        sub = session.execute(stmt).scalar()
        if sub and sub.ai_minutes_used < sub.ai_minutes_total:
            sub.is_track_active = True
            sub.track_started_at = datetime.now(UTC).replace(tzinfo=None)
            sub.last_deduction_at = sub.track_started_at
            session.commit()
            return True
    return False


if __name__ == "__main__":
    manager = AICreditManager()
    asyncio.run(manager.run())
