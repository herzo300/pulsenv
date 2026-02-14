import hmac
import hashlib
import os
from fastapi import HTTPException, status, Depends
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError

SECRET_KEY = os.getenv("JWT_SECRET") or "default-secret-key-change-in-production"
ALGORITHM = "HS256"
BOT_TOKEN = os.getenv("BOT_TOKEN")

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")


def verify_telegram_data(data: dict) -> bool:
    """Проверка подписи данных от Telegram"""
    check_hash = data.pop('hash', None)
    if not check_hash:
        return False

    items = sorted([f"{k}={v}" for k, v in data.items()])
    data_check_string = "\n".join(items)

    if not BOT_TOKEN:
        return False

    secret_key = hashlib.sha256(BOT_TOKEN.encode()).digest()
    hash_value = hmac.new(secret_key, data_check_string.encode(), hashlib.sha256).hexdigest()

    return hash_value == check_hash


def create_access_token(data: dict):
    to_encode = data.copy()
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
