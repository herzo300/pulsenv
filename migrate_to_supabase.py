import os
import sqlite3
import logging
from datetime import datetime, timezone
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("MigrateFixed")

def load_env_vars():
    env = {}
    env_path = "c:/Soobshio_project/.env"
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    env[k.strip()] = v.strip().strip('"')
    return env

def row_to_dict(row):
    return {k: row[k] for k in row.keys()}

def migrate():
    env = load_env_vars()
    
    # Supabase credentials
    ref = env.get("SUPABASE_PROJECT_REF", "xpainxohbdoruakcijyq")
    password = env.get("SUPABASE_DB_PASSWORD", "1aWh3j7a3TaHtEUd")
    
    user = f"postgres.{ref}"
    host = f"aws-1-eu-west-3.pooler.supabase.com"
    port = 6543
    dbname = "postgres"
    
    db_url = f"postgresql://{user}:{password}@{host}:{port}/{dbname}"
    
    sqlite_path = "c:/Soobshio_project/soobshio.db"
    if not os.path.exists(sqlite_path):
        logger.error(f"SQLite file not found at {sqlite_path}")
        return

    logger.info(f"Connecting to Postgres as {user}")
    pg_engine = create_engine(db_url)
    PgSession = sessionmaker(bind=pg_engine)
    pg_session = PgSession()

    sqlite_conn = sqlite3.connect(sqlite_path)
    sqlite_conn.row_factory = sqlite3.Row
    sqlite_curr = sqlite_conn.cursor()

    try:
        # 1. Migrate Users
        sqlite_curr.execute("SELECT * FROM users")
        rows = sqlite_curr.fetchall()
        logger.info(f"Checking {len(rows)} users...")
        
        for row in rows:
            u = row_to_dict(row)
            tid = u["telegram_id"]
            if not tid: continue
            res = pg_session.execute(text("SELECT id FROM users WHERE telegram_id = :tid"), {"tid": tid}).fetchone()
            if not res:
                pg_session.execute(text(
                    "INSERT INTO users (telegram_id, username, first_name, last_name, photo_url, balance, created_at) "
                    "VALUES (:tid, :user, :first, :last, :photo, :bal, :created)"
                ), {
                    "tid": tid,
                    "user": u["username"],
                    "first": u.get("first_name", ""),
                    "last": u.get("last_name", ""),
                    "photo": u.get("photo_url", ""),
                    "bal": u.get("balance", 0),
                    "created": u.get("created_at") or datetime.now(timezone.utc)
                })
        pg_session.commit()
        logger.info("Users OK.")

        # 2. Migrate Reports
        sqlite_curr.execute("SELECT * FROM reports")
        rows = sqlite_curr.fetchall()
        logger.info(f"Migrating {len(rows)} reports...")
        
        for row in rows:
            r = row_to_dict(row)
            res = pg_session.execute(text("SELECT id FROM reports WHERE id = :id"), {"id": r["id"]}).fetchone()
            if not res:
                uid_local = r["user_id"]
                pg_uid = None
                if uid_local:
                    u_row = sqlite_conn.execute("SELECT telegram_id FROM users WHERE id = ?", (uid_local,)).fetchone()
                    if u_row:
                        tid = u_row["telegram_id"]
                        res_uid = pg_session.execute(text("SELECT id FROM users WHERE telegram_id = :tid"), {"tid": tid}).fetchone()
                        if res_uid: pg_uid = res_uid[0]

                pg_session.execute(text(
                    "INSERT INTO reports (id, user_id, title, description, lat, lng, address, category, status, source, created_at) "
                    "VALUES (:id, :uid, :title, :desc, :lat, :lng, :addr, :cat, :status, :src, :created)"
                ), {
                    "id": r["id"],
                    "uid": pg_uid,
                    "title": r["title"],
                    "desc": r["description"],
                    "lat": r["lat"],
                    "lng": r["lng"],
                    "addr": r["address"],
                    "cat": r["category"],
                    "status": r["status"],
                    "src": r.get("source", "sqlite_migrated"),
                    "created": r.get("created_at") or datetime.now(timezone.utc)
                })
        pg_session.commit()
        logger.info("Reports OK.")

    except Exception as e:
        logger.error(f"Migration error: {e}")
        pg_session.rollback()
    finally:
        sqlite_conn.close()
        pg_session.close()

if __name__ == "__main__":
    migrate()
