#!/bin/bash
set -eu -o pipefail
cd /root/citypulse_api

PGPW=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
echo "compose_pw_len=${#PGPW}"
docker compose exec -T backend printenv DATABASE_URL | sed 's#.*://soobshio:[^@]*@#postgresql://soobshio:***@#'

docker compose exec -T postgres psql -U soobshio -d postgres -v ON_ERROR_STOP=1 \
  -c "ALTER USER soobshio WITH PASSWORD '${PGPW}';"

docker compose restart backend
sleep 12

docker compose exec -T backend python - <<'PY'
import os
from sqlalchemy import create_engine, text

engine = create_engine(os.environ["DATABASE_URL"])
with engine.connect() as conn:
    count = conn.execute(text("SELECT count(*) FROM reports")).scalar()
    print("db_ok", count)
PY

curl -s http://127.0.0.1:8000/health
echo
curl -s http://127.0.0.1:8000/api/pulse/stats | head -c 250
echo
