#!/usr/bin/env python3
"""Тест real-time маркирования на карте"""
import asyncio
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

from services.firebase_service import push_complaint

async def main():
    # Тестовая жалоба с адресом и координатами
    test_complaint = {
        'category': 'Освещение',
        'summary': 'Не горит фонарь на ул. Ленина 15',
        'text': 'На ул. Ленина 15 не работает уличное освещение уже неделю. Темно и опасно для пешеходов.',
        'address': 'ул. Ленина, 15, Нижневартовск',
        'lat': 60.9344,
        'lng': 76.5531,
        'source': 'test_realtime',
        'source_name': 'Тест Real-time',
        'provider': 'manual'
    }
    
    print('[TEST] Создаю тестовую жалобу с адресом для проверки real-time маркирования...')
    print(f'   Категория: {test_complaint["category"]}')
    print(f'   Адрес: {test_complaint["address"]}')
    print(f'   Координаты: {test_complaint["lat"]}, {test_complaint["lng"]}')
    
    result = await push_complaint(test_complaint)
    
    if result:
        print(f'[OK] Жалоба создана в Firebase: {result}')
        print('[INFO] Откройте карту в браузере/Telegram Web App')
        print('   Маркер должен появиться автоматически в течение 3 секунд')
    else:
        print('[ERROR] Ошибка создания жалобы')

if __name__ == '__main__':
    asyncio.run(main())
