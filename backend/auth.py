"""Compatibility re-exports — prefer ``services.data_layer.auth`` directly."""

from services.data_layer.auth import (  # noqa: F401
    ALGORITHM,
    BOT_TOKEN,
    SECRET_KEY,
    create_access_token,
    get_current_user,
    oauth2_scheme,
    verify_telegram_data,
)
