# services/Backend/routers/payments.py
import logging
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel

from services.data_layer.database import get_db
from services.data_layer.auth import get_user_from_request
from services.data_layer.models import User
from services.business.yookassa_service import create_yookassa_payment, process_yookassa_webhook

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["payments"])

class CreatePaymentResponse(BaseModel):
    payment_id: str
    confirmation_url: str
    is_mock: bool

@router.post("/payments/create", response_model=CreatePaymentResponse)
async def create_payment_endpoint(
    request: Request,
    db: Session = Depends(get_db)
):
    """Create a redirect payment session to purchase Premium subscription."""
    # Ensure user is authenticated
    try:
        user = await get_user_from_request(request, db)
    except Exception:
        raise HTTPException(status_code=401, detail="Authentication required to make payments.")
        
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Standard premium price: 199.00 RUB
    result = await create_yookassa_payment(user_id=user.id, amount=199.00)
    
    if "error" in result:
        raise HTTPException(status_code=500, detail=result["error"])
        
    return result


@router.post("/payments/webhook/yookassa")
async def yookassa_webhook_endpoint(
    request: Request,
    db: Session = Depends(get_db)
):
    """Receive succeeded payment notifications from YooKassa and grant Premium."""
    try:
        event_payload = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid request body")
        
    logger.info(f"Received YooKassa webhook payload: {event_payload}")
    
    # Process webhook event
    success = await process_yookassa_webhook(event_payload, db)
    
    if not success:
        # Returning 200 OK anyway to let YooKassa know we received the event, 
        # but log the failure so we don't cause YooKassa to retry dead tasks.
        logger.warning("Webhook processing skipped or failed, returned 200 to acknowledge.")
        
    return {"status": "ok"}
