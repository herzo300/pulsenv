#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Миграция бэкенда на Supabase PostgreSQL.
Использует SUPABASE (Management API token) и SUPABASE_DB_PASSWORD из .env.
Проект: https://xpainxohbdoruakcijyq.supabase.co
Справка: https://supabase.com/docs/reference/api/introduction
"""

import os
import sys
from pathlib import Path
from urllib.parse import quote_plus

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))
os.chdir(ROOT)

# Загружаем .env до импорта backend
from dotenv import load_dotenv
load_dotenv(ROOT / ".env")

# Прокси для подключения (SOCKS_PROXY из .env)
def _install_proxy():
    import socket
    proxy_url = os.getenv("SOCKS_PROXY", "").strip() or os.getenv("HTTP_PROXY", "").strip()
    if not proxy_url or "://" not in proxy_url:
        return None
    if proxy_url.startswith("socks"):
        try:
            import socks
            from urllib.parse import urlparse
            u = urlparse(proxy_url)
            host, port = u.hostname or "127.0.0.1", u.port or 1080
            socks.set_default_proxy(socks.SOCKS5, host, port)
            orig = socket.socket
            socket.socket = socks.socksocket
            return orig
        except ImportError:
            return None
    return None

def _restore_socket(orig):
    if orig is not None:
        import socket
        socket.socket = orig

_orig_socket = _install_proxy()
if _orig_socket:
    print("Proksi vkluchen:", os.getenv("SOCKS_PROXY", "") or os.getenv("HTTP_PROXY", ""))

SUPABASE_PROJECT_REF = os.getenv("SUPABASE_PROJECT_REF", "xpainxohbdoruakcijyq")
SUPABASE_DB_PASSWORD = os.getenv("SUPABASE_DB_PASSWORD", "")
SUPABASE_ACCESS_TOKEN = os.getenv("SUPABASE_ACCESS_TOKEN", os.getenv("SUPABASE", ""))
DATABASE_URL_CURRENT = os.getenv("DATABASE_URL", "")


def _api_get(path):
    """GET Supabase Management API."""
    if not SUPABASE_ACCESS_TOKEN:
        return None
    try:
        import urllib.request
        req = urllib.request.Request(
            f"https://api.supabase.com/v1/projects/{SUPABASE_PROJECT_REF}{path}",
            headers={"Authorization": f"Bearer {SUPABASE_ACCESS_TOKEN}"},
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            import json
            return json.loads(r.read().decode())
    except Exception:
        return None


def get_pooler_url():
    """Build URL from pooler config API (correct host/region). Returns (url, None) or (None, error)."""
    data = _api_get("/config/database/pooler")
    if not data:
        return None, "no response"
    pool = data[0] if isinstance(data, list) and len(data) > 0 else (data if isinstance(data, dict) else None)
    if not pool:
        return None, "invalid format"
    host = pool.get("db_host") or (pool.get("connection_string") or "").split("@")[-1].split("/")[0].split(":")[0]
    port = pool.get("db_port", 6543)
    user = pool.get("db_user") or f"postgres.{SUPABASE_PROJECT_REF}"
    db_name = pool.get("db_name", "postgres")
    if not host:
        return None, "db_host missing"
    pass_enc = quote_plus(SUPABASE_DB_PASSWORD)
    url = f"postgresql://{user}:{pass_enc}@{host}:{port}/{db_name}"
    return url, None


def main():
    # Already have Postgres/Supabase URL
    if DATABASE_URL_CURRENT and ("postgresql" in DATABASE_URL_CURRENT or "postgres://" in DATABASE_URL_CURRENT):
        url = DATABASE_URL_CURRENT
        if "YOUR_PASSWORD" in url or "[YOUR-PASSWORD]" in url or "PAROL" in url or (url.count(":") >= 2 and (not url.split(":")[2] or url.split(":")[2].startswith("["))):
            print("ERROR: V DATABASE_URL ukazan placeholder parolya. Zamenite na realnyj parol BD iz Supabase Dashboard -> Settings -> Database.")
            sys.exit(1)
    elif SUPABASE_DB_PASSWORD:
        url, err = get_pooler_url()
        if url is None and SUPABASE_ACCESS_TOKEN:
            proj = _api_get("")  # GET /v1/projects/{ref}
            if isinstance(proj, dict) and proj.get("region"):
                pass_enc = quote_plus(SUPABASE_DB_PASSWORD)
                user = f"postgres.{SUPABASE_PROJECT_REF}"
                url = f"postgresql://{user}:{pass_enc}@aws-0-{proj['region']}.pooler.supabase.com:6543/postgres"
        if url is None:
            # Try pooler regions (transaction mode 6543)
            pass_enc = quote_plus(SUPABASE_DB_PASSWORD)
            user = f"postgres.{SUPABASE_PROJECT_REF}"
            regions = (
                "eu-west-1", "eu-central-1", "eu-central-2", "eu-north-1",
                "us-east-1", "us-west-1", "ap-southeast-1", "ap-northeast-1",
            )
            for region in regions:
                candidate = f"postgresql://{user}:{pass_enc}@aws-0-{region}.pooler.supabase.com:6543/postgres"
                try:
                    from sqlalchemy import create_engine
                    e = create_engine(candidate, connect_args={"connect_timeout": 5})
                    e.connect().close()
                    url = candidate
                    print(f"Podklyuchenie OK (region={region}).")
                    break
                except Exception as ex:
                    err = str(ex).split("\n")[0][:80]
                    if "Tenant or user not found" in str(ex):
                        continue
                    print(f"  {region}: {err}")
                    continue
        if url is None:
            print("Ne udalos podklyuchitsya po regionam. Skopiruyte Connection string (URI)")
            print("iz Supabase Dashboard -> Project Settings -> Database i vstavte v .env:")
            print("  DATABASE_URL=postgresql://postgres.[ref]:[PAROL]@aws-0-[REGION].pooler.supabase.com:6543/postgres")
            print("Zatem zapustite skript snova: py scripts/setup/migrate_supabase.py")
            sys.exit(1)
        os.environ["DATABASE_URL"] = url
    else:
        print("Migraciya na Supabase: zadayte v .env odin iz variantov:")
        print("  1) SUPABASE_DB_PASSWORD=parol_iz_dashboard (parol BD: Settings -> Database)")
        print("  2) DATABASE_URL=postgresql://postgres.xpainxohbdoruakcijyq:PAROL@aws-0-eu-central-1.pooler.supabase.com:6543/postgres")
        print("Management API token (SUPABASE ili SUPABASE_ACCESS_TOKEN) opcionalen dlya regiona.")
        sys.exit(1)

    # Переустанавливаем DATABASE_URL для текущего процесса
    os.environ["DATABASE_URL"] = url

    # Импорт после установки DATABASE_URL
    from backend.database import engine
    from backend.models import Base

    print(f"Podklyuchenie k Supabase (ref={SUPABASE_PROJECT_REF})...")
    try:
        Base.metadata.create_all(bind=engine)
        print("OK: Tablicy sozdany (users, reports, likes, comments).")
        print("Dlya postoyannoj raboty ustanovite v .env DATABASE_URL i perezapustite servisy.")
    except Exception as e:
        err = str(e)
        if "could not translate host name" in err and "db." in url and ".supabase.co" in url:
            print("DNS ne razreshaet host db.xxx.supabase.co v etoj srede.")
            print("Zapustite migraciyu u sebya na PK:  py scripts/setup/migrate_supabase.py")
            print("Ili v .env vstavte URI Connection pooling iz Dashboard:")
            print("  Settings -> Database -> Connection string -> URI (Transaction, port 6543)")
            print("  postgresql://postgres.REF:PASSWORD@aws-0-REGION.pooler.supabase.com:6543/postgres")
        else:
            raise


if __name__ == "__main__":
    try:
        main()
    finally:
        _restore_socket(_orig_socket)
