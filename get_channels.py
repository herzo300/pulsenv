#!/usr/bin/env python3
"""
Получить список всех каналов с ID
"""

import asyncio
import os
from dotenv import load_dotenv
from telethon import TelegramClient

load_dotenv()

API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')

async def main():
    print("🔍 Получение списка каналов...")
    
    client = TelegramClient('monitoring_session', API_ID, API_HASH)
    
    try:
        await client.connect()
        
        if not await client.is_user_authorized():
            print("❌ Не авторизован. Запустите auth_with_code.py")
            return
        
        me = await client.get_me()
        print(f"✅ Авторизован как: {me.first_name}\n")
        
        print("📋 Список каналов:\n")
        print(f"{'ID':<20} {'Название':<50} {'Username':<30}")
        print("-" * 100)
        
        channels = []
        async for dialog in client.iter_dialogs():
            if dialog.is_channel:
                channel_id = dialog.id
                title = dialog.title or "Без названия"
                username = f"@{dialog.entity.username}" if dialog.entity.username else "Нет username"
                
                print(f"{channel_id:<20} {title:<50} {username:<30}")
                channels.append({
                    'id': channel_id,
                    'title': title,
                    'username': username
                })
        
        print("\n" + "=" * 100)
        print(f"\n✅ Найдено каналов: {len(channels)}\n")
        
        # Сохраняем в файл
        import json
        with open('channels_list.json', 'w', encoding='utf-8') as f:
            json.dump(channels, f, ensure_ascii=False, indent=2)
        
        print("💾 Список сохранен в channels_list.json")
        
        # Показываем каналы для мониторинга
        print("\n📡 Каналы для мониторинга (из .env):")
        monitoring_channels = [
            '@nizhnevartovsk_chp',
            '@Nizhnevartovskd',
            '@chp_nv_86',
            '@accidents_in_nizhnevartovsk',
            '@Nizhnevartovsk_podslushal',
            '@justnow_nv',
            '@nv86_me',
            '@adm_nvartovsk',
        ]
        
        for ch in monitoring_channels:
            found = next((c for c in channels if c['username'] == ch), None)
            if found:
                print(f"  ✅ {ch:<40} ID: {found['id']}")
            else:
                print(f"  ❌ {ch:<40} Не найден (возможно не подписаны)")
        
        # Показываем целевой канал
        print("\n📢 Целевой канал для публикации:")
        target_channel = os.getenv('TARGET_CHANNEL', '')
        if target_channel:
            try:
                target_id = int(target_channel)
                found = next((c for c in channels if c['id'] == target_id), None)
                if found:
                    print(f"  ✅ {found['title']:<40} ID: {target_id}")
                    print(f"     Username: {found['username']}")
                else:
                    print(f"  ⚠️  ID: {target_id} - Канал не найден в списке")
                    print(f"     Возможно нужно добавить аккаунт в канал")
            except ValueError:
                print(f"  ⚠️  {target_channel} - Некорректный ID")
        else:
            print("  ❌ TARGET_CHANNEL не указан в .env")
        
        await client.disconnect()
        
    except Exception as e:
        print(f"❌ Ошибка: {e}")
        await client.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
