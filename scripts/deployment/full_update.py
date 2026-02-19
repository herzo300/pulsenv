#!/usr/bin/env python3
"""
Полный цикл обновления: деплой Cloudflare Worker → обновление бота (версия + меню).

Использование:
  py scripts/deployment/full_update.py           # деплой Worker + обновление бота
  py scripts/deployment/full_update.py --no-deploy   # только обновление бота (меню + bump версии)
  py scripts/deployment/full_update.py --deploy-only # только деплой Worker
"""
import argparse
import subprocess
import sys
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main():
    parser = argparse.ArgumentParser(description="Полный цикл: деплой Worker и/или обновление бота")
    parser.add_argument("--no-deploy", action="store_true", help="Не запускать деплой Worker, только обновить бота")
    parser.add_argument("--deploy-only", action="store_true", help="Только деплой Worker, не обновлять бота")
    parser.add_argument("--wait", type=int, default=0, metavar="SEC", help="Ждать N секунд после деплоя перед обновлением бота")
    args = parser.parse_args()

    do_deploy = not args.no_deploy
    do_bot = not args.deploy_only

    deploy_script = os.path.join(ROOT, "scripts", "deployment", "deploy_now.py")
    bot_script = os.path.join(ROOT, "scripts", "maintenance", "update_and_verify_bot.py")

    if do_deploy:
        print("=" * 50)
        print("  1/2  Деплой Cloudflare Worker")
        print("=" * 50)
        r = subprocess.run([sys.executable, deploy_script], cwd=ROOT)
        if r.returncode != 0:
            print("Деплой завершился с ошибкой. Обновление бота пропущено.")
            return r.returncode
        if args.wait > 0:
            print(f"Ожидание {args.wait} с перед обновлением бота...")
            import time
            time.sleep(args.wait)
    else:
        print("Деплой Worker пропущен (--no-deploy)")

    if do_bot:
        print()
        print("=" * 50)
        print("  2/2  Обновление бота (версия + меню)")
        print("=" * 50)
        r = subprocess.run([sys.executable, bot_script], cwd=ROOT)
        if r.returncode != 0:
            return r.returncode
    else:
        print("Обновление бота пропущено (--deploy-only)")

    print()
    print("Готово.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
