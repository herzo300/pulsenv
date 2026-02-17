#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Скрипт для обновления дизайна карты и инфографики
Обновляет цветовую схему, эффекты и версионирование
"""

import re
import os
from datetime import datetime

WORKER_FILE = "cloudflare-worker/worker.js"

def update_design_colors(content):
    """Обновляет цветовую схему на более современную"""
    
    # Новая цветовая палитра - более яркие и современные цвета
    color_updates = {
        # Основные цвета - более яркие неоновые оттенки
        '--primary: #00f0ff': '--primary: #00d9ff',  # Более яркий циан
        '--primary-light: #33f3ff': '--primary-light: #4de6ff',  # Ярче
        '--primary-dark: #00c8d4': '--primary-dark: #00b8d4',  # Глубже
        
        # Успех - более яркий зеленый
        '--success: #00ff88': '--success: #00ff99',  # Ярче
        
        # Опасность - более насыщенный красный
        '--danger: #ff3366': '--danger: #ff2d5f',  # Ярче
        
        # Предупреждение - более яркий оранжевый
        '--warning: #ffaa00': '--warning: #ffb800',  # Ярче
        
        # Фон - более глубокий темный
        '--bg: #0a0a0f': '--bg: #050508',  # Глубже
        
        # Поверхность - более прозрачная с эффектом стекла
        '--surface: rgba(10, 15, 30, 0.95)': '--surface: rgba(10, 15, 30, 0.92)',
        
        # Тени - более яркие неоновые эффекты
        '--shadow: 0 0 30px rgba(0, 240, 255, 0.3), 0 4px 20px rgba(0, 0, 0, 0.8)': 
        '--shadow: 0 0 40px rgba(0, 217, 255, 0.4), 0 0 60px rgba(0, 255, 153, 0.2), 0 4px 20px rgba(0, 0, 0, 0.8)',
        
        '--shadow-glow: 0 0 40px rgba(0, 240, 255, 0.5), 0 0 80px rgba(0, 255, 136, 0.3)':
        '--shadow-glow: 0 0 50px rgba(0, 217, 255, 0.6), 0 0 100px rgba(0, 255, 153, 0.4), 0 0 150px rgba(0, 217, 255, 0.2)',
    }
    
    for old, new in color_updates.items():
        content = content.replace(old, new)
    
    return content

def update_aurora_effects(content):
    """Улучшает эффекты северного сияния"""
    
    # Обновляем эффекты Aurora для более яркого сияния
    aurora_updates = {
        # Увеличиваем opacity для более яркого эффекта
        'opacity: 0.6': 'opacity: 0.75',
        
        # Обновляем градиенты для более яркого сияния
        'rgba(0, 240, 255, 0.03)': 'rgba(0, 217, 255, 0.05)',
        'rgba(0, 240, 255, 0.05)': 'rgba(0, 217, 255, 0.08)',
        'rgba(0, 255, 136, 0.3)': 'rgba(0, 255, 153, 0.4)',
    }
    
    for old, new in aurora_updates.items():
        content = content.replace(old, new)
    
    return content

def improve_versioning(content):
    """Улучшает версионирование для обхода кэша"""
    
    # Обновляем мета-тег версии с более точным timestamp
    version_pattern = r'<meta name="app-version" content="([^"]+)">'
    
    def replace_version(match):
        # Используем текущий timestamp для версии
        timestamp = int(datetime.now().timestamp())
        return f'<meta name="app-version" content="{timestamp}">'
    
    content = re.sub(version_pattern, replace_version, content)
    
    # Улучшаем заголовки Cache-Control
    cache_headers = [
        ('Cache-Control: no-cache, no-store, must-revalidate, max-age=0', 
         'Cache-Control: no-cache, no-store, must-revalidate, max-age=0, private'),
        ('Cache-Control: "text/html;charset=utf-8"', 
         'Cache-Control: no-cache, no-store, must-revalidate'),
    ]
    
    return content

def update_info_versioning(content):
    """Добавляет версионирование для инфографики"""
    
    # Добавляем версию в заголовок инфографики если её нет
    if '<meta name="app-version"' not in content:
        # Ищем title и добавляем после него
        title_pattern = r'(<title>[^<]+</title>)'
        timestamp = int(datetime.now().timestamp())
        version_meta = f'\\1\n<meta name="app-version" content="{timestamp}">'
        content = re.sub(title_pattern, version_meta, content, count=1)
    
    return content

def main():
    """Главная функция обновления"""
    print("=" * 60)
    print("OBNOVLENIE DIZAYNA KARTY I INFOGRAFIKI")
    print("=" * 60)
    
    if not os.path.exists(WORKER_FILE):
        print(f"ERROR: File {WORKER_FILE} not found")
        return 1
    
    print(f"\nReading file {WORKER_FILE}...")
    with open(WORKER_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_size = len(content)
    print(f"   Размер файла: {original_size:,} символов")
    
    print("\nUpdating color scheme...")
    content = update_design_colors(content)
    
    print("Improving aurora effects...")
    content = update_aurora_effects(content)
    
    print("Improving versioning...")
    content = improve_versioning(content)
    
    # Обновляем версионирование для инфографики
    print("Updating infographic versioning...")
    content = update_info_versioning(content)
    
    # Сохраняем обновленный файл
    print(f"\nSaving updated file...")
    with open(WORKER_FILE, 'w', encoding='utf-8') as f:
        f.write(content)
    
    new_size = len(content)
    print(f"   Новый размер: {new_size:,} символов")
    print(f"   Изменение: {new_size - original_size:+,} символов")
    
    print("\nSUCCESS: Design updated!")
    print("\nChanges:")
    print("   - Updated color palette (brighter neon colors)")
    print("   - Improved aurora effects")
    print("   - Improved versioning for cache bypass")
    print("   - Added versioning for infographic")
    
    return 0

if __name__ == "__main__":
    try:
        exit_code = main()
        exit(exit_code)
    except Exception as e:
        import traceback
        print(f"\nERROR: {e}")
        traceback.print_exc()
        exit(1)
