import uuid
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import httpx

router = APIRouter()

# TODO: Перенести ключи в переменные окружения (.env)
YANDEX_SHOP_ID = "YOUR_SHOP_ID"
YANDEX_SECRET_KEY = "YOUR_SECRET_KEY"

class PaymentRequest(BaseModel):
    amount: float
    description: str
    user_id: str

@router.post("/create")
async def create_payment(request: PaymentRequest):
    """
    Создает платеж для VIP-подписки или услуг (самозанятый).
    """
    async with httpx.AsyncClient() as client:
        payload = {
            "amount": {
                "value": f"{request.amount:.2f}",
                "currency": "RUB"
            },
            "capture": True,
            "confirmation": {
                "type": "redirect",
                "return_url": "https://pulsgoroda.ru/payment/success"
            },
            "description": request.description,
            "metadata": {
                "user_id": request.user_id
            }
        }
        headers = {
            "Idempotence-Key": str(uuid.uuid4()),
            "Content-Type": "application/json"
        }
        
        response = await client.post(
            "https://api.yookassa.ru/v3/payments",
            json=payload,
            headers=headers,
            auth=(YANDEX_SHOP_ID, YANDEX_SECRET_KEY)
        )
        
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code, detail=f"Ошибка Yookassa: {response.text}")
            
        data = response.json()
        return {
            "payment_id": data.get("id"),
            "status": data.get("status"),
            "confirmation_url": data.get("confirmation", {}).get("confirmation_url")
        }

@router.post("/webhook")
async def yookassa_webhook(payload: dict):
    """
    Вебхук для получения статусов от ЮKassa.
    """
    event = payload.get("event")
    payment_object = payload.get("object", {})
    payment_id = payment_object.get("id")
    status = payment_object.get("status")
    metadata = payment_object.get("metadata", {})
    
    if event == "payment.succeeded":
        # TODO: Активировать VIP подписку пользователю `metadata.get('user_id')`
        pass
        
    return {"status": "ok"}
