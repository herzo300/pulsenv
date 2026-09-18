#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-/opt/soobshio/.env.production}"
BACKUP_DIR="${2:-/opt/soobshio/backups}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "env file not found: $ENV_FILE" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
cd "$PROJECT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_DIR="$BACKUP_DIR/$TIMESTAMP"
mkdir -p "$ARCHIVE_DIR"

set -a
source "$ENV_FILE"
set +a

docker compose --env-file "$ENV_FILE" exec -T postgres pg_dump \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  > "$ARCHIVE_DIR/postgres.sql"

docker run --rm \
  -v runtime_uploads:/source:ro \
  -v "$ARCHIVE_DIR:/backup" \
  alpine:3.20 \
  sh -c 'cd /source && tar -czf /backup/uploads.tar.gz .'

cp "$ENV_FILE" "$ARCHIVE_DIR/env.snapshot"

echo "backup saved to $ARCHIVE_DIR"
