import hashlib
import hmac
import os
import sys

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

_SECRET_ENV = os.getenv("JWT_SECRET")
if not _SECRET_ENV:
    print(
        "FATAL: JWT_SECRET is not set! Application cannot start securely. "
        "Set JWT_SECRET in your .env file.",
        file=sys.stderr,
    )
    sys.exit(1)

# Reject insecure default values
_INSECURE_SECRETS = {"change_me", "secret", "test", "123456", "password", "changeme"}
if _SECRET_ENV.lower() in _INSECURE_SECRETS or len(_SECRET_ENV) < 16:
    print(
        "FATAL: JWT_SECRET is too weak or uses a default value! "
        "Use a random string of at least 32 characters.",
        file=sys.stderr,
    )
    sys.exit(1)

SECRET_KEY = _SECRET_ENV
ALGORITHM = "HS256"
BOT_TOKEN = os.getenv("BOT_TOKEN") or os.getenv("TG_BOT_TOKEN")

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")


def verify_telegram_data(data: dict) -> bool:
    """Проверка подписи данных от Telegram"""
    check_hash = data.pop("hash", None)
    if not check_hash:
        return False

    items = sorted([f"{k}={v}" for k, v in data.items()])
    data_check_string = "\n".join(items)

    if not BOT_TOKEN:
        return False

    secret_key = hashlib.sha256(BOT_TOKEN.encode()).digest()
    hash_value = hmac.new(
        secret_key, data_check_string.encode(), hashlib.sha256
    ).hexdigest()

    return hash_value == check_hash


def create_access_token(data: dict):
    to_encode = data.copy()
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="token", auto_error=False)


async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )


async def get_optional_current_user(token: str | None = Depends(oauth2_scheme_optional)) -> dict | None:
    if not token:
        return None
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None


def verify_telegram_init_string(init_data_str: str) -> dict | None:
    """Verifies Telegram WebApp initData string using HMAC-SHA256 signature algorithm."""
    if not init_data_str or not BOT_TOKEN:
        return None
    try:
        from urllib.parse import parse_qs, unquote
        parsed = parse_qs(init_data_str, keep_blank_values=True)
        hash_val = parsed.get("hash", [None])[0]
        if not hash_val:
            return None
        
        # Build data_check_string
        data_pairs = []
        for k, v in parsed.items():
            if k != "hash":
                data_pairs.append(f"{k}={v[0]}")
        data_pairs.sort()
        data_check_string = "\n".join(data_pairs)
        
        secret_key = hmac.new(b"WebAppData", BOT_TOKEN.encode(), hashlib.sha256).digest()
        calculated_hash = hmac.new(secret_key, data_check_string.encode(), hashlib.sha256).hexdigest()
        
        if hmac.compare_digest(calculated_hash, hash_val):
            import json
            user_json = parsed.get("user", [None])[0]
            if user_json:
                return json.loads(user_json)
    except Exception:
        pass
    return None


async def get_user_from_request(request, db):
    """Helper to extract user securely from request headers, query params or JSON body."""
    auth_header = request.headers.get("Authorization")
    token = None
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
    else:
        token = request.query_params.get("token")
        
    if token:
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            user_id = payload.get("user_id") or payload.get("sub")
            if user_id:
                from services.data_layer.models import User as DBUser
                return db.query(DBUser).filter(DBUser.id == int(user_id)).first()
        except Exception:
            pass

    # Verify Telegram WebApp init_data header or param securely
    init_data = request.headers.get("X-Telegram-Init-Data") or request.query_params.get("init_data")
    if init_data:
        tg_user_data = verify_telegram_init_string(init_data)
        if tg_user_data and "id" in tg_user_data:
            try:
                from services.data_layer.models import User as DBUser
                tg_int = int(tg_user_data["id"])
                user = db.query(DBUser).filter(DBUser.telegram_id == tg_int).first()
                if not user:
                    user = DBUser(telegram_id=tg_int, username=tg_user_data.get("username", ""))
                    db.add(user)
                    db.commit()
                    db.refresh(user)
                return user
            except Exception:
                pass

    # Development fallback strictly gated by ENV check
    if os.getenv("ENVIRONMENT") == "development":
        tg_id = request.query_params.get("telegram_id") or request.headers.get("X-Telegram-Id")
        if tg_id:
            try:
                from services.data_layer.models import User as DBUser
                tg_int = int(tg_id)
                user = db.query(DBUser).filter(DBUser.telegram_id == tg_int).first()
                if not user:
                    user = DBUser(telegram_id=tg_int)
                    db.add(user)
                    db.commit()
                    db.refresh(user)
                return user
            except Exception:
                pass
            
    return None

