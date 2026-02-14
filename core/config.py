from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    DATABASE_URL: str = "sqlite:///./soobshio.db"
    TG_API_ID: Optional[int] = None
    TG_API_HASH: Optional[str] = None
    ANTHROPIC_API_KEY: Optional[str] = None
    JWT_SECRET: Optional[str] = None
    BOT_TOKEN: Optional[str] = None
    TARGET_CHANNEL: Optional[str] = None
    TG_PHONE: Optional[str] = None
    OPENAI_API_KEY: Optional[str] = None
    ZAI_API_KEY: Optional[str] = None
    GEMINI_API_KEY: Optional[str] = None

    model_config = {
        "env_file": ".env",
        "extra": "allow"
    }

settings = Settings()
