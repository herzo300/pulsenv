#!/bin/bash
TOKEN=$(sed -n 's/^TG_BOT_TOKEN=//p' /opt/soobshio/.env | tr -d '"')
echo "=== via tor ==="
timeout 30 curl -sS --proxy socks5h://tor:9050 "https://api.telegram.org/bot${TOKEN}/getWebhookInfo" 2>&1 | head -c 300
echo
echo "=== direct ==="
timeout 30 curl -sS "https://api.telegram.org/bot${TOKEN}/getWebhookInfo" 2>&1 | head -c 300
echo
echo "=== getMe tor ==="
timeout 30 curl -sS --proxy socks5h://tor:9050 "https://api.telegram.org/bot${TOKEN}/getMe" 2>&1 | head -c 300
echo
