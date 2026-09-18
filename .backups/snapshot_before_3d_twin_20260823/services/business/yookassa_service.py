# services/business/yookassa_service.py
import os
import uuid
import logging
import httpx
import base64
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from services.data_layer.models import User

logger = logging.getLogger(__name__)

# Credentials configuration
SHOP_ID = os.getenv("YOOKASSA_SHOP_ID", "")
API_KEY = os.getenv("YOOKASSA_API_KEY", "")
API_BASE = "https://api.yookassa.ru/v3"

async def create_yookassa_payment(user_id: int, email: str = None, amount: float = 199.00) -> dict:
    """Create a redirect payment session in YooKassa for subscription upgrade."""
    logger.info(f"Creating YooKassa payment session for user #{user_id}...")
    
    if not SHOP_ID or not API_KEY:
        logger.warning("YooKassa credentials are not configured. Falling back to sandbox/mock payment link.")
        # Return mock payment session for dev / testing
        mock_payment_id = str(uuid.uuid4())
        return {
            "payment_id": mock_payment_id,
            "confirmation_url": f"https://api.nv/mock-payment?id={mock_payment_id}&user_id={user_id}&amount={amount}",
            "is_mock": True
        }

    # Prepare YooKassa API call headers
    auth_str = base64.b64encode(f"{SHOP_ID}:{API_KEY}".encode()).decode()
    headers = {
        "Authorization": f"Basic {auth_str}",
        "Content-Type": "application/json",
        "Idempotence-Key": str(uuid.uuid4()) # Unique key per request
    }
    
    # Request body structure
    payload = {
        "amount": {
            "value": f"{amount:.2f}",
            "currency": "RUB"
        },
        "capture": True,
        "confirmation": {
            "type": "redirect",
            "return_url": "https://api.nv/payment/success" # Target redirect URL after checkout
        },
        "description": "Подписка Premium (City Pulse / СообщиО) — 1 месяц",
        "metadata": {
            "user_id": str(user_id)
        }
    }
    
    # Include receipt contact details if available
    if email:
        payload["receipt"] = {
            "items": [
                {
                    "description": "Подписка Premium City Pulse",
                    "quantity": "1.00",
                    "amount": {
                        "value": f"{amount:.2f}",
                        "currency": "RUB"
                    },
                    "vat_code": "1" # VAT 20%
                }
            ],
            "customer": {
                "email": email
            }
        }
        
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(f"{API_BASE}/payments", json=payload, headers=headers)
            
            if resp.status_code == 200 or resp.status_code == 201:
                data = resp.json()
                payment_id = data.get("id")
                confirm_url = data.get("confirmation", {}).get("confirmation_url")
                
                logger.info(f"YooKassa payment created: {payment_id} | URL: {confirm_url}")
                return {
                    "payment_id": payment_id,
                    "confirmation_url": confirm_url,
                    "is_mock": False
                }
            else:
                logger.error(f"YooKassa payment creation failed: {resp.status_code} {resp.text}")
                return {"error": f"YooKassa API returned error code {resp.status_code}"}
                
    except Exception as e:
        logger.error(f"Failed to call YooKassa payments API: {e}")
        return {"error": str(e)}


async def process_yookassa_webhook(event_payload: dict, db: Session) -> bool:
    """Handle YooKassa payment.succeeded webhook and grant Premium subscription."""
    logger.info("Processing YooKassa webhook event...")
    
    event_type = event_payload.get("event")
    if event_type != "payment.succeeded":
        logger.info(f"Skipping non-success event: {event_type}")
        return False
        
    payment_object = event_payload.get("object", {})
    payment_id = payment_object.get("id")
    status = payment_object.get("status")
    
    if status != "succeeded":
        logger.info(f"Payment object is not in succeeded status: {status}")
        return False
        
    # Extract metadata containing user identifier
    metadata = payment_object.get("metadata", {})
    user_id_str = metadata.get("user_id")
    
    if not user_id_str:
        logger.error(f"User ID missing in payment metadata for payment {payment_id}!")
        return False
        
    try:
        user_id = int(user_id_str)
        user = db.query(User).filter(User.id == user_id).first()
        
        if not user:
            logger.error(f"User #{user_id} not found in database for successful payment!")
            return False
            
        # Grant or extend subscription by 30 days
        now = datetime.utcnow()
        current_end = user.digest_subscription_until or now
        # If subscription was expired, start from now
        start_date = current_end if current_end > now else now
        
        new_end = start_date + timedelta(days=30)
        user.digest_subscription_until = new_end
        db.commit()
        
        logger.info(
            f"🎉 Premium access successfully granted to user #{user_id} ({user.first_name} {user.last_name}) "
            f"until {new_end.strftime('%d.%m.%Y %H:%M:%S')} (Payment ID: {payment_id})"
        )
        return True
    except Exception as e:
        logger.error(f"Failed to process successful subscription grant: {e}")
        db.rollback()
        return False
