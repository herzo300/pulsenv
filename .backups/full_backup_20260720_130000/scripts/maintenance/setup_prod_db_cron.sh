#!/usr/bin/env bash
# Install weekly DB maintenance on production (Sunday 04:30 UTC).
set -eu -o pipefail

ROOT="/root/citypulse_api"
CRON_LINE="30 4 * * 0 cd ${ROOT} && /usr/bin/python3 scripts/maintenance/run_prod_db_maintenance.py --vacuum >> /var/log/soobshio_db_maint.log 2>&1"

mkdir -p "${ROOT}/scripts/maintenance"
touch /var/log/soobshio_db_maint.log

if crontab -l 2>/dev/null | grep -F "run_prod_db_maintenance.py" >/dev/null; then
  echo "cron already installed"
else
  (crontab -l 2>/dev/null; echo "${CRON_LINE}") | crontab -
  echo "cron installed"
fi

crontab -l | grep -F "run_prod_db_maintenance.py" || true
