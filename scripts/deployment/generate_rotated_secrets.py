#!/usr/bin/env python3
"""Generate rotated secrets locally (never commit output)."""
from __future__ import annotations

import secrets
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "secrets-rotation-2026.env"
DOMAIN = "45-153-68-59.sslip.io"

lines = [
    "# Soobshio secret rotation — generated locally, DO NOT COMMIT",
    f"# Created: {datetime.now(UTC).isoformat()}",
    "# Copy to VPS: scp secrets-rotation-2026.env root@VPS:/opt/soobshio/",
    "# Apply on VPS: bash scripts/deployment/rotate_secrets.sh /opt/soobshio",
    "",
    f"PUBLIC_API_BASE_URL=https://{DOMAIN}",
    f"BACKEND_CORS_ORIGINS=https://{DOMAIN},http://127.0.0.1,http://localhost",
    "PRODUCTION=true",
    "DB_AUTO_CREATE=false",
    "",
    f"JWT_SECRET={secrets.token_urlsafe(48)}",
    f"ADMIN_API_TOKEN={secrets.token_urlsafe(32)}",
    f"ADMIN_2FA_PASSWORD={secrets.token_hex(16)}",
    f"POSTGRES_PASSWORD={secrets.token_hex(24)}",
    f"REDIS_PASSWORD={secrets.token_hex(24)}",
    f"LITELLM_MASTER_KEY={secrets.token_hex(32)}",
    f"VISERON_WEBHOOK_TOKEN={secrets.token_hex(24)}",
    "",
    "# External keys below — rotate manually in provider dashboards, then paste here before apply:",
    "# TG_BOT_TOKEN=          # @BotFather -> /revoke then new token",
    "# TG_API_HASH=           # https://my.telegram.org",
    "# TIMEWEB_TOKEN=         # Timeweb cloud panel -> API keys",
    "# ZAI_API_KEY=           # Z.AI / BigModel console",
    "# OPENAI_API_KEY=        # OpenRouter or OpenAI dashboard",
    "# OPENROUTER_MODEL=      # (non-secret, model name only)",
    "# VK_SERVICE_TOKEN=      # VK dev portal",
    "# RESEND_API_KEY=        # Resend dashboard",
    "# YOOKASSA_SECRET_KEY=   # YooKassa merchant cabinet",
    "# NV_OPENDATA_API_KEY=   # NV opendata portal",
    "# GEMMA_CLOUD_API_KEY=   # OpenRouter/Groq",
    "# FISH_AUDIO_API_KEY=    # Fish Audio console",
    "# ELEVENLABS_API_KEY=    # ElevenLabs profile -> API keys",
    "# GOOGLE_APPLICATION_CREDENTIALS=  # Firebase/GCP — rotate service account key",
    "",
]

OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"Wrote {OUT}")
