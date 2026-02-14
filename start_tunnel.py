"""Запуск ngrok туннеля для Telegram Web App"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pyngrok import ngrok, conf
import time

# Настройка
PORT = 8000

print("🚀 Запуск ngrok туннеля...")
try:
    tunnel = ngrok.connect(PORT, "http")
    public_url = tunnel.public_url
    
    # Убедимся что HTTPS
    if public_url.startswith("http://"):
        public_url = public_url.replace("http://", "https://")
    
    print(f"✅ Туннель запущен!")
    print(f"🌐 Public URL: {public_url}")
    print(f"📂 OpenData WebApp: {public_url}/map/opendata.html")
    print(f"🗺️ Map: {public_url}/map/map.html")
    print()
    
    # Сохраняем URL в файл для бота
    with open("tunnel_url.txt", "w") as f:
        f.write(public_url)
    
    print(f"💾 URL сохранён в tunnel_url.txt")
    print(f"⏳ Туннель активен. Ctrl+C для остановки.")
    print()
    
    # Держим туннель открытым
    while True:
        time.sleep(1)
        
except KeyboardInterrupt:
    print("\n⏹️ Туннель остановлен")
    ngrok.kill()
except Exception as e:
    print(f"❌ Ошибка: {e}")
    print("Попробуйте: py -m pip install pyngrok")
