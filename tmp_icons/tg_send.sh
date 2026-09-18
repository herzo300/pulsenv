#!/bin/bash
TOKEN=$(sed -n 's/^TG_BOT_TOKEN=//p' /opt/soobshio/.env | tr -d '"')
APK=/opt/soobshio/public/app-arm64-v8a-release.apk
# Find chat: try known admin patterns via getUpdates through tor
CHAT=""
for PROXY in "socks5h://tor:9050" ""; do
  RESP=$(timeout 30 curl -sS ${PROXY:+--proxy $PROXY} "https://api.telegram.org/bot${TOKEN}/getUpdates?limit=10" 2>/dev/null)
  if [ -n "$RESP" ] && echo "$RESP" | grep -q '"ok":true'; then
    CHAT=$(echo "$RESP" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    for u in d.get('result',[]):
        m=u.get('message') or u.get('edited_message') or {}
        c=m.get('chat',{})
        if c.get('id'): print(c['id']); break
except: pass
")
    if [ -n "$CHAT" ]; then
      echo "ROUTE=${PROXY:-direct} CHAT=$CHAT"
      break
    fi
  fi
done
if [ -z "$CHAT" ]; then
  echo "NO_CHAT_FOUND"
  exit 1
fi
timeout 120 curl -sS ${PROXY:+--proxy $PROXY} "https://api.telegram.org/bot${TOKEN}/sendDocument"   -F "chat_id=${CHAT}" -F "document=@${APK}"   -F "caption=Пульс города v1.0.3 (ARM64) — продакшен-сборка: бегущая строка со свайпом, светлый Гермес, fullscreen-эффекты камер, WebGL-двойник. MD5: 5f630bc9e8b64205b054fc11d3880402" | head -c 300
echo
