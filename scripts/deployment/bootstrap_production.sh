#!/usr/bin/env bash
# Bootstrap Soobshio stack on Timeweb VPS (run as root on the server).
set -eu -o pipefail

PROJECT_DIR="${1:-/root/citypulse_api}"
ENV_FILE="${PROJECT_DIR}/.env"

echo "==> Soobshio production bootstrap"
echo "    project: ${PROJECT_DIR}"

if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "ERROR: project dir not found: ${PROJECT_DIR}" >&2
  exit 1
fi

cd "${PROJECT_DIR}"

# Host nginx often conflicts with Docker on :80/:443 and returns 500 without valid TLS.
if systemctl is-active --quiet nginx 2>/dev/null; then
  echo "==> Stopping host nginx (conflicts with Docker soobshio_nginx)"
  systemctl stop nginx || true
  systemctl disable nginx || true
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${PROJECT_DIR}/.env.production.template" ]]; then
    cp "${PROJECT_DIR}/.env.production.template" "${ENV_FILE}"
    echo "==> Created ${ENV_FILE} from template — EDIT SECRETS before continuing"
  else
    echo "ERROR: ${ENV_FILE} missing" >&2
    exit 1
  fi
fi

# Required compose variables
grep -q '^POSTGRES_PASSWORD=' "${ENV_FILE}" || echo 'POSTGRES_PASSWORD=change_me_now' >> "${ENV_FILE}"
grep -q '^REDIS_PASSWORD=' "${ENV_FILE}" || echo 'REDIS_PASSWORD=change_me_now' >> "${ENV_FILE}"
grep -q '^PUBLIC_API_BASE_URL=' "${ENV_FILE}" || echo 'PUBLIC_API_BASE_URL=http://127.0.0.1' >> "${ENV_FILE}"
grep -q '^PRODUCTION=' "${ENV_FILE}" || echo 'PRODUCTION=true' >> "${ENV_FILE}"

if ! grep -q '^JWT_SECRET=.\+' "${ENV_FILE}"; then
  secret="$(openssl rand -hex 32 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(32))')"
  echo "JWT_SECRET=${secret}" >> "${ENV_FILE}"
  echo "==> Generated JWT_SECRET"
fi

if ! grep -q '^ADMIN_API_TOKEN=.\+' "${ENV_FILE}"; then
  token="$(openssl rand -hex 16 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(16))')"
  echo "ADMIN_API_TOKEN=${token}" >> "${ENV_FILE}"
fi

# Keep DATABASE_URL in sync with POSTGRES_* for Docker postgres service.
PG_USER="$(grep '^POSTGRES_USER=' "${ENV_FILE}" | tail -1 | cut -d= -f2- | tr -d '"' | tr -d ' ')"
PG_DB="$(grep '^POSTGRES_DB=' "${ENV_FILE}" | tail -1 | cut -d= -f2- | tr -d '"' | tr -d ' ')"
PG_PASS="$(grep '^POSTGRES_PASSWORD=' "${ENV_FILE}" | tail -1 | cut -d= -f2- | tr -d '"' )"
PG_USER="${PG_USER:-soobshio}"
PG_DB="${PG_DB:-soobshio}"
grep -q '^POSTGRES_USER=' "${ENV_FILE}" || echo "POSTGRES_USER=${PG_USER}" >> "${ENV_FILE}"
grep -q '^POSTGRES_DB=' "${ENV_FILE}" || echo "POSTGRES_DB=${PG_DB}" >> "${ENV_FILE}"
if [[ -n "${PG_PASS}" ]]; then
  expected="postgresql+psycopg2://${PG_USER}:${PG_PASS}@postgres:5432/${PG_DB}"
  if grep -q '^DATABASE_URL=' "${ENV_FILE}"; then
    sed -i "s|^DATABASE_URL=.*|DATABASE_URL=${expected}|" "${ENV_FILE}"
  else
    echo "DATABASE_URL=${expected}" >> "${ENV_FILE}"
  fi
fi

# Telethon session for monitoring container
mkdir -p "${PROJECT_DIR}/session"
if [[ -f "${PROJECT_DIR}/monitoring_session.session" && ! -f "${PROJECT_DIR}/session/monitoring_session.session" ]]; then
  cp "${PROJECT_DIR}/monitoring_session.session" "${PROJECT_DIR}/session/monitoring_session.session"
  echo "==> Copied Telethon session into ./session/"
fi

echo "==> Building and starting stack"
docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d --build postgres redis backend nginx
docker compose --profile monitoring up -d --build monitoring camera_probe viseron 2>/dev/null || true

# Optional local AI stack (Ollama + LiteLLM)
ENABLE_AI_STACK="${ENABLE_AI_STACK:-false}"
if grep -q '^ENABLE_AI_STACK=' "${ENV_FILE}" 2>/dev/null; then
  ENABLE_AI_STACK="$(grep '^ENABLE_AI_STACK=' "${ENV_FILE}" | tail -1 | cut -d= -f2- | tr -d '"' | tr '[:upper:]' '[:lower:]')"
fi
if [[ "${ENABLE_AI_STACK}" == "true" || "${ENABLE_AI_STACK}" == "1" || "${ENABLE_AI_STACK}" == "yes" ]]; then
  echo "==> Starting AI profile (ollama + litellm)"
  docker compose --profile ai up -d --build ollama litellm 2>/dev/null || true
  grep -q '^ENABLE_AI_STACK=' "${ENV_FILE}" || echo 'ENABLE_AI_STACK=true' >> "${ENV_FILE}"
  for i in $(seq 1 20); do
    if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
      echo "    ollama OK"
      break
    fi
    sleep 3
  done
fi

if ! grep -q '^VISERON_WEBHOOK_TOKEN=.\+' "${ENV_FILE}"; then
  viseron_token="$(openssl rand -hex 24 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(24))')"
  echo "VISERON_WEBHOOK_TOKEN=${viseron_token}" >> "${ENV_FILE}"
  echo "==> Generated VISERON_WEBHOOK_TOKEN"
fi
grep -q '^VISERON_ENABLED=' "${ENV_FILE}" || echo 'VISERON_ENABLED=true' >> "${ENV_FILE}"

echo "==> Waiting for backend health"
for i in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:8000/health" >/dev/null 2>&1; then
    echo "    backend OK"
    break
  fi
  sleep 2
done

echo "==> Alembic migrations (best effort)"
docker compose exec -T backend alembic upgrade head 2>/dev/null || true

echo "==> Public checks"
curl -sS "http://127.0.0.1/healthz" || true
echo
curl -sS "http://127.0.0.1/health" | head -c 400 || true
echo
curl -sS "http://127.0.0.1/api/map/feed?limit=3" | head -c 400 || true
echo

docker compose ps
echo "==> Done. Open http://$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')/map"
