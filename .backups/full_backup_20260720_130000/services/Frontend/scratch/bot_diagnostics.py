"""
Diagnostics script to test the Telegram bot and VK API.
Checks token validity, bot username, and target channel connection.
"""
import sys
import os
import urllib.request
import json
import sqlite3
from datetime import datetime, timedelta

sys.stdout.reconfigure(encoding='utf-8')

# Load environment from project root
env_path = "c:/Soobshio_project/.env"
if os.path.exists(env_path):
    print("Loading .env...")
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.strip().split("=", 1)
                os.environ[k] = v.strip().replace('"', '')

bot_token = os.getenv("TG_BOT_TOKEN")
target_channel = os.getenv("TARGET_CHANNEL")
vk_token = os.getenv("VK_SERVICE_TOKEN")

print(f"BOT TOKEN: {bot_token[:10]}... if configured else None")
print(f"TARGET CHANNEL: {target_channel}")
print(f"VK SERVICE TOKEN: {vk_token[:10] if vk_token else 'None'}... if configured else None")

def test_telegram_bot():
    if not bot_token:
        print("❌ TG_BOT_TOKEN is not configured in .env")
        return
    
    url = f"https://api.telegram.org/bot{bot_token}/getMe"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "CityPulse-Diagnostics/1.0"})
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data.get("ok"):
                result = data["result"]
                print(f"✅ TG Bot connection: SUCCESS")
                print(f"   Name: {result.get('first_name')}")
                print(f"   Username: @{result.get('username')}")
                print(f"   Can join groups: {result.get('can_join_groups')}")
            else:
                print(f"❌ TG Bot API returned error: {data}")
    except Exception as e:
        print(f"❌ TG Bot connection failed: {e}")

def test_target_channel():
    if not bot_token or not target_channel:
        print("❌ TG_BOT_TOKEN or TARGET_CHANNEL is not configured")
        return
    
    # Try sending a test message or checking channel chat details
    url = f"https://api.telegram.org/bot{bot_token}/getChat?chat_id={target_channel}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "CityPulse-Diagnostics/1.0"})
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data.get("ok"):
                result = data["result"]
                print(f"✅ Target Channel Access: SUCCESS")
                print(f"   Title: {result.get('title')}")
                print(f"   Type: {result.get('type')}")
                if result.get('username'):
                    print(f"   Username: @{result.get('username')}")
            else:
                print(f"❌ Target Channel API returned error: {data}")
    except Exception as e:
        print(f"❌ Target Channel Access failed: {e} (Make sure bot is an Administrator in the channel)")

def check_database_reports():
    db_path = "c:/Soobshio_project/soobshio.db"
    if not os.path.exists(db_path):
        print(f"❌ Database not found at {db_path}")
        return
    
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    
    # Count reports in last 2 days
    two_days_ago = (datetime.now() - timedelta(days=2)).strftime("%Y-%m-%d %H:%M:%S")
    c.execute("SELECT COUNT(*), city FROM reports WHERE created_at >= ? GROUP BY city", (two_days_ago,))
    rows = c.fetchall()
    
    print("\n📊 Database reports count in the last 2 days:")
    if not rows:
        print("   No reports found.")
    for count, city in rows:
        print(f"   {city or 'unknown'}: {count} reports")
        
    c.execute("SELECT id, title, created_at, status, city FROM reports WHERE created_at >= ? ORDER BY id DESC LIMIT 5", (two_days_ago,))
    latest = c.fetchall()
    print("\n🆕 Latest reports added in the last 2 days:")
    for row in latest:
        print(f"   ID {row[0]}: {row[1][:40]}... ({row[2]}) | Status: {row[3]} | City: {row[4]}")
        
    conn.close()

if __name__ == "__main__":
    print("=== City Pulse Ingestion & Bot Diagnostics ===")
    test_telegram_bot()
    test_target_channel()
    check_database_reports()
