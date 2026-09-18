# Secret rotation checklist (Soobshio / Пульс города)

Generated secrets for **server-side** keys live in `secrets-rotation-2026.env` (gitignored). Never commit that file.

## Server-side (automated)

Run on the VPS:

```bash
cd /opt/soobshio
bash scripts/deployment/rotate_secrets.sh /opt/soobshio secrets-rotation-2026.env
```

Rotates: `JWT_SECRET`, `ADMIN_API_TOKEN`, `ADMIN_2FA_PASSWORD`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `LITELLM_MASTER_KEY`, `VISERON_WEBHOOK_TOKEN`, and sets `PUBLIC_API_BASE_URL` to HTTPS.

## External dashboards (manual)

| Service | Where to rotate | Notes |
|---------|-----------------|-------|
| **Telegram Bot** | [@BotFather](https://t.me/BotFather) → `/revoke` then `/token` | Update `TG_BOT_TOKEN` in production `.env`; restart `bot`/`monitoring` |
| **Telegram API** | [my.telegram.org](https://my.telegram.org) | `TG_API_ID`, `TG_API_HASH` — create new app if compromised |
| **Timeweb API** | Timeweb Cloud → API keys | `TIMEWEB_TOKEN` — revoke old key in panel |
| **Timeweb SSH** | Timeweb VPS → Access / root password | Change root password; update local `.env` `SSH_PASSWORD` only on your machine |
| **OpenRouter / OpenAI** | [openrouter.ai/keys](https://openrouter.ai/keys) or OpenAI dashboard | `OPENAI_API_KEY`, `GEMMA_CLOUD_API_KEY` |
| **Z.AI / BigModel** | Z.AI console | `ZAI_API_KEY` |
| **VK** | [vk.com/dev](https://vk.com/dev) | `VK_SERVICE_TOKEN` |
| **Resend** | Resend → API Keys | `RESEND_API_KEY` |
| **YooKassa** | Merchant cabinet | `YOOKASSA_SECRET_KEY` |
| **NV OpenData** | Regional portal | `NV_OPENDATA_API_KEY` |
| **Fish Audio** | Fish Audio dashboard | `FISH_AUDIO_API_KEY` |
| **ElevenLabs** | Profile → API Keys | `ELEVENLABS_API_KEY` |
| **Firebase / Google** | GCP Console → Service accounts | Rotate JSON key; never commit `firebase-*.json` |
| **WAQI / Air quality** | WAQI token page | `WAQI_API_TOKEN` |

## Exposed in git history (action required)

Historical commits may contain real values in `.env.example`, `scratch/*`, and deployment scripts (SSH password literals). Even after rotation, consider:

1. `git filter-repo` or BFG to purge secrets from history before making the repo public
2. Revoke every key that ever appeared in a committed file

## TLS domain

Production HTTPS uses **`45-153-68-59.sslip.io`** (Let's Encrypt cert on VPS). For a custom domain (e.g. `pulsgoroda.ru`), point DNS A-record to the VPS IP, then:

```bash
SOOBSHIO_PUBLIC_DOMAIN=pulsgoroda.ru bash scripts/deployment/rotate_secrets.sh /opt/soobshio
certbot certonly --nginx -d pulsgoroda.ru
# Update ops/timeweb/nginx.conf ssl_certificate paths to match
```
