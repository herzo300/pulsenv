#!/usr/bin/env bash
set -eu -o pipefail

ENV_FILE="${1:-/opt/soobshio/.env.production}"
PROJECT_DIR="${2:-/opt/soobshio}"
COMPOSE=(docker compose --env-file "$ENV_FILE")
SERVICES=(postgres redis backend bot monitoring nginx)

if [[ ! -f "$ENV_FILE" ]]; then
  echo "env file not found: $ENV_FILE" >&2
  exit 1
fi

cd "$PROJECT_DIR"

restart_stack() {
  echo "healthcheck: restarting stack"
  "${COMPOSE[@]}" up -d
}

container_status() {
  local name="$1"
  docker inspect --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$name" 2>/dev/null || true
}

for service in "${SERVICES[@]}"; do
  if ! "${COMPOSE[@]}" ps --services --status running | grep -qx "$service"; then
    echo "healthcheck: service $service is not running"
    restart_stack
    exit 0
  fi
done

backend_state="$(container_status soobshio_backend)"
nginx_state="$(container_status soobshio_nginx)"

if [[ "$backend_state" != *healthy* ]]; then
  echo "healthcheck: backend state is '$backend_state'"
  restart_stack
  exit 0
fi

if [[ "$nginx_state" != *healthy* ]]; then
  echo "healthcheck: nginx state is '$nginx_state'"
  restart_stack
  exit 0
fi

if ! curl -fsS --max-time 10 http://127.0.0.1/health >/dev/null; then
  echo "healthcheck: public /health failed"
  restart_stack
  exit 0
fi

if ! curl -fsS --max-time 10 http://127.0.0.1/ >/dev/null; then
  echo "healthcheck: public root failed"
  restart_stack
  exit 0
fi

echo "healthcheck: stack is healthy"
