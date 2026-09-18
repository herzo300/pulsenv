#!/bin/bash
TOKEN=$(sed -n 's/^TG_BOT_TOKEN=//p' /opt/soobshio/.env | tr -d '"')
echo "---getMe---"
timeout 25 curl -sS "https://api.telegram.org/bot${TOKEN}/getMe"
echo
echo "---getWebhookInfo---"
timeout 25 curl -sS "https://api.telegram.org/bot${TOKEN}/getWebhookInfo"
echo
echo "---sendMessage test to bot admin (0=error expected)---"
timeout 25 curl -sS "https://api.telegram.org/bot${TOKEN}/sendMessage" -d "chat_id=0" -d "text=test" | head -c 200
