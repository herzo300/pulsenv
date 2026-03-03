#!/usr/bin/env python3
"""Удаление дубликатов постов из канала @monitornv"""
import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
os.chdir(sys.path[0])

from dotenv import load_dotenv
load_dotenv()

from telethon import TelegramClient
from collections import defaultdict

API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')
PASSWORD_2FA = os.getenv('TG_2FA_PASSWORD', '')
TARGET_CHANNEL = '@monitornv'


async def remove_duplicates():
    """Находит и удаляет дубликаты постов в канале"""
    client = TelegramClient('soobshio_cleanup', API_ID, API_HASH)
    await client.start(phone=PHONE, password=PASSWORD_2FA)
    
    print(f"📡 Подключено к каналу {TARGET_CHANNEL}")
    
    # Получаем последние 200 сообщений
    messages = await client.get_messages(TARGET_CHANNEL, limit=200)
    print(f"📋 Получено {len(messages)} сообщений")
    
    # Группируем по ключам (адрес, координаты, первые 50 символов текста)
    groups = defaultdict(list)
    
    for msg in messages:
        if not msg.text:
            continue
        
        text = msg.text.lower()
        
        # Извлекаем ключи для группировки
        keys = []
        
        # По адресу (если есть)
        if "📍" in msg.text:
            addr_start = msg.text.find("📍") + 2
            addr_end = msg.text.find("\n", addr_start)
            if addr_end == -1:
                addr_end = len(msg.text)
            address = msg.text[addr_start:addr_end].strip()
            if address and len(address) > 5:
                keys.append(f"addr:{address.lower()[:50]}")
        
        # По координатам (если есть)
        if "🗺️" in msg.text:
            coords_start = msg.text.find("🗺️") + 2
            coords_end = msg.text.find("\n", coords_start)
            if coords_end == -1:
                coords_end = len(msg.text)
            coords = msg.text[coords_start:coords_end].strip()
            if coords and "," in coords:
                keys.append(f"coord:{coords[:20]}")
        
        # По первым словам сводки
        if "📝" in msg.text:
            summary_start = msg.text.find("📝") + 2
            summary_end = msg.text.find("\n", summary_start)
            if summary_end == -1:
                summary_end = summary_start + 80
            summary = msg.text[summary_start:summary_end].strip()[:50]
            if summary:
                keys.append(f"text:{summary.lower()}")
        
        # Добавляем сообщение в группы
        if keys:
            # Используем первый ключ для группировки
            key = keys[0]
            groups[key].append((msg.id, msg.date, msg.text))
    
    # Находим дубликаты (группы с >1 сообщением)
    duplicates = []
    for key, msgs in groups.items():
        if len(msgs) > 1:
            # Сортируем по дате (старые первыми)
            msgs.sort(key=lambda x: x[1])
            # Оставляем самое новое, остальные — дубликаты
            duplicates.extend([m[0] for m in msgs[:-1]])
    
    print(f"🔍 Найдено {len(duplicates)} дубликатов")
    
    if duplicates:
        confirm = input(f"Удалить {len(duplicates)} дубликатов? (yes/no): ")
        if confirm.lower() == 'yes':
            deleted = 0
            for msg_id in duplicates:
                try:
                    await client.delete_messages(TARGET_CHANNEL, msg_id)
                    deleted += 1
                    if deleted % 10 == 0:
                        print(f"Удалено {deleted}/{len(duplicates)}...")
                except Exception as e:
                    print(f"Ошибка удаления {msg_id}: {e}")
            print(f"✅ Удалено {deleted} дубликатов")
        else:
            print("Отменено")
    else:
        print("✅ Дубликатов не найдено")
    
    await client.disconnect()


if __name__ == "__main__":
    asyncio.run(remove_duplicates())
