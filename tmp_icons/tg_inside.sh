#!/bin/bash
# Runs INSIDE backend container where 'tor' hostname resolves
TOKEN=$(sed -n 's/^TG_BOT_TOKEN=//p' /opt/soobshio/.env | tr -d '"')
echo "=== getMe via tor ==="
timeout 30 curl -sS --proxy socks5h://tor:9050 "https://api.telegram.org/bot${TOKEN}/getMe" 2>&1 | head -c 300
echo
echo "=== getUpdates via tor ==="
timeout 30 curl -sS --proxy socks5h://tor:9050 "https://api.telegram.org/bot${TOKEN}/getUpdates?limit=10" 2>&1 | head -c 500
echo
echo "=== direct ==="
timeout 20 curl -sS "https://api.telegram.org/bot${TOKEN}/getMe" 2>&1 | head -c 200
echo
