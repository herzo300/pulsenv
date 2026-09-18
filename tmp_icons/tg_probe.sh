#!/bin/bash
# Find bot chats and optionally send APK to Telegram
TOKEN=$(sed -n 's/^TG_BOT_TOKEN=//p' /opt/soobshio/.env | tr -d '"')
echo "token_len=${#TOKEN}"
echo "---getUpdates---"
timeout 25 curl -sS "https://api.telegram.org/bot${TOKEN}/getUpdates?limit=5" | head -c 900
echo
