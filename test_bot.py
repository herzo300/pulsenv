#!/usr/bin/env python3
# Test Telegram bot command handling

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Test imports
print("Testing imports...")
try:
    from backend.database import SessionLocal
    from backend.models import Report
    print("Database imports OK")
except Exception as e:
    print(f"Database import failed: {e}")
    sys.exit(1)

# Test command handlers
print("\nTesting command handlers...")
try:
    from services.telegram_bot import dp
    print("Command handlers loaded")
except Exception as e:
    print(f"Command handlers failed to load: {e}")
    sys.exit(1)

print("\nAll tests passed!")
print("\nStarting bot...")
