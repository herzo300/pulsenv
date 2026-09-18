import sqlite3
import os
import sys
from datetime import datetime
from sqlalchemy.orm import Session

# Setup path
sys.path.insert(0, "/app")

from services.data_layer.database import SessionLocal
from services.data_layer.models import Report

SQLITE_PATH = "/app/data/soobshio_sync.db"

def main():
    if not os.path.exists(SQLITE_PATH):
        print(f"SQLite database not found at {SQLITE_PATH}")
        sys.exit(1)

    print("Connecting to SQLite database...")
    sqlite_conn = sqlite3.connect(SQLITE_PATH)
    sqlite_cur = sqlite_conn.cursor()
    
    sqlite_cur.execute(
        "SELECT id, title, description, address, lat, lng, category, status, source, city, created_at FROM reports"
    )
    sqlite_reports = sqlite_cur.fetchall()
    print(f"Loaded {len(sqlite_reports)} reports from SQLite.")

    print("Connecting to PostgreSQL database...")
    db: Session = SessionLocal()

    inserted_count = 0
    updated_count = 0

    try:
        for row in sqlite_reports:
            r_id, r_title, r_desc, r_addr, r_lat, r_lng, r_cat, r_status, r_source, r_city, r_created_at = row
            
            # Convert created_at string to datetime
            created_dt = None
            if r_created_at:
                try:
                    created_dt = datetime.fromisoformat(r_created_at)
                except Exception:
                    try:
                        created_dt = datetime.strptime(r_created_at, "%Y-%m-%d %H:%M:%S")
                    except Exception as e:
                        print(f"Warning parsing date '{r_created_at}' for ID {r_id}: {e}")

            # Check if report exists in PostgreSQL
            pg_report = db.query(Report).filter(Report.id == r_id).first()
            
            # If not found by ID, try finding by title and city
            if not pg_report and r_title:
                pg_report = db.query(Report).filter(Report.title == r_title, Report.city == r_city).first()

            if pg_report:
                # Update existing report
                pg_report.title = r_title
                pg_report.description = r_desc
                pg_report.address = r_addr
                pg_report.lat = r_lat
                pg_report.lng = r_lng
                pg_report.category = r_cat
                pg_report.status = r_status
                pg_report.source = r_source
                pg_report.city = r_city
                if created_dt:
                    pg_report.created_at = created_dt
                
                updated_count += 1
            else:
                # Insert new report
                new_report = Report(
                    id=r_id,
                    title=r_title,
                    description=r_desc,
                    address=r_addr,
                    lat=r_lat,
                    lng=r_lng,
                    category=r_cat,
                    status=r_status,
                    source=r_source,
                    city=r_city,
                    created_at=created_dt
                )
                db.add(new_report)
                inserted_count += 1

        db.commit()
        print(f"Synchronization completed successfully!")
        print(f"   Updated: {updated_count} reports")
        print(f"   Inserted: {inserted_count} reports")
    except Exception as e:
        db.rollback()
        print(f"Error during synchronization: {e}")
        sys.exit(1)
    finally:
        db.close()
        sqlite_conn.close()

if __name__ == "__main__":
    main()
