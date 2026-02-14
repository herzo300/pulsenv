import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from backend.database import SessionLocal
    from backend.models import Report
    print("Imports successful")
    db = SessionLocal()
    print("Database session created")
    try:
        reports = db.query(Report).limit(5).all()
        print(f"Found {len(reports)} reports")
    finally:
        db.close()
        print("Database session closed")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
