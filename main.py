#!/usr/bin/env python3
# Точка входа API: делегирует в services/Backend (вариант 2).
# Запуск: python main.py  или  python -m services.Backend.main
import os
import sys
import uvicorn

from services.Backend.app import app

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    try:
        uvicorn.run(app, host="0.0.0.0", port=port)
    except OSError as e:
        in_use_win = getattr(e, "winerror", None) == 10048
        in_use_unix = getattr(e, "errno", None) == 98
        if in_use_win or in_use_unix:
            print(f"[ERROR] Port {port} already in use.", file=sys.stderr)
            print("  Free it: netstat -ano | findstr :%s" % port, file=sys.stderr)
            print("  Then: taskkill /PID <pid> /F", file=sys.stderr)
            print("  Or set another port: set PORT=8001 && py main.py", file=sys.stderr)
        raise
