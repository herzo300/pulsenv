#!/usr/bin/env bash
# Rotate Soobshio server-side secrets and apply TLS-ready env URLs.
# Run ON the VPS as root:
#   bash scripts/deployment/rotate_secrets.sh /opt/soobshio
#
# Optional: pass a rotation file with new values:
#   bash scripts/deployment/rotate_secrets.sh /opt/soobshio /opt/soobshio/secrets-rotation-2026.env
set -eu -o pipefail

PROJECT_DIR="${1:-/opt/soobshio}"
ROTATION_FILE="${2:-${PROJECT_DIR}/secrets-rotation-2026.env}"
ENV_FILE="${PROJECT_DIR}/.env"
DOMAIN="${SOOBSHIO_PUBLIC_DOMAIN:-45-153-68-59.sslip.io}"
TS="$(date +%Y%m%d-%H%M%S)"

if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "ERROR: project dir not found: ${PROJECT_DIR}" >&2
  exit 1
fi

cd "${PROJECT_DIR}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} missing" >&2
  exit 1
fi

cp "${ENV_FILE}" "${ENV_FILE}.bak.${TS}"
echo "==> Backed up env to ${ENV_FILE}.bak.${TS}"

_gen() {
  openssl rand -hex 32 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(32))'
}

_gen_b64() {
  openssl rand -base64 32 2>/dev/null || python3 -c 'import secrets; print(secrets.token_urlsafe(32))'
}

set_or_append() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "${ENV_FILE}"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${ENV_FILE}"
  else
    echo "${key}=${value}" >> "${ENV_FILE}"
  fi
}

apply_from_rotation_file() {
  if [[ ! -f "${ROTATION_FILE}" ]]; then
    return 1
  fi
  echo "==> Applying rotation values from ${ROTATION_FILE}"
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" =~ ^# ]] && continue
    [[ -z "${line// }" ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    [[ -z "${key}" || -z "${val}" ]] && continue
    case "${key}" in
      TG_*|OPENAI_*|ZAI_*|VK_*|RESEND_*|YOOKASSA_*|NV_*|GEMMA_*|FISH_*|ELEVENLABS_*|TIMEWEB_*|SSH_*|DATABASE_URL)
        continue
        ;;
    esac
    set_or_append "${key}" "${val}"
  done < "${ROTATION_FILE}"
  return 0
}

if ! apply_from_rotation_file; then
  echo "==> Generating fresh secrets on server"
  set_or_append "JWT_SECRET" "$(_gen_b64)"
  set_or_append "ADMIN_API_TOKEN" "$(_gen_b64)"
  set_or_append "ADMIN_2FA_PASSWORD" "$(_gen)"
  set_or_append "POSTGRES_PASSWORD" "$(_gen)"
  set_or_append "REDIS_PASSWORD" "$(_gen)"
  set_or_append "LITELLM_MASTER_KEY" "$(_gen)"
  set_or_append "VISERON_WEBHOOK_TOKEN" "$(_gen)"
fi

set_or_append "PUBLIC_API_BASE_URL" "https://${DOMAIN}"
set_or_append "BACKEND_CORS_ORIGINS" "https://${DOMAIN},http://127.0.0.1,http://localhost"
set_or_append "PRODUCTION" "true"
set_or_append "DB_AUTO_CREATE" "false"

PG_USER="$(grep '^POSTGRES_USER=' "${ENV_FILE}" | tail -1 | cut -d= -f2- | tr -d '"' | tr -d ' ')"
PG_DB="$(grep '^POSTGRES_DB=' "${ENV_FILE}" | tail -1 | cut -d= -f2- | tr -d '"' | tr -d ' ')"
PG_PASS="$(grep '^POSTGRES_PASSWORD=' "${ENV_FILE}" | tail -1 | cut -d= -f2- | tr -d '"' )"
PG_USER="${PG_USER:-soobshio}"
PG_DB="${PG_DB:-soobshio}"
set_or_append "POSTGRES_USER" "${PG_USER}"
set_or_append "POSTGRES_DB" "${PG_DB}"
python3 - <<PY
from pathlib import Path
from urllib.parse import quote_plus
import re
env_path = Path("${ENV_FILE}")
text = env_path.read_text()
pg_user = "${PG_USER}"
pg_db = "${PG_DB}"
pg_pass = "${PG_PASS}"
url = f"postgresql+psycopg2://{pg_user}:{quote_plus(pg_pass)}@postgres:5432/{pg_db}"
if re.search(r'^DATABASE_URL=', text, re.M):
    text = re.sub(r'^DATABASE_URL=.*$', f'DATABASE_URL={url}', text, count=1, flags=re.M)
else:
    text = text.rstrip() + f"\nDATABASE_URL={url}\n"
env_path.write_text(text)
PY

echo "==> Updating PostgreSQL user password (if postgres is running)"
if docker compose ps postgres 2>/dev/null | grep -q Up; then
  docker compose exec -T postgres psql -U "${PG_USER}" -d "${PG_DB}" \
    -c "ALTER USER ${PG_USER} WITH PASSWORD '${PG_PASS}';" 2>/dev/null || \
  docker compose exec -T postgres psql -U postgres -d postgres \
    -c "ALTER USER ${PG_USER} WITH PASSWORD '${PG_PASS}';" 2>/dev/null || \
  echo "WARN: could not ALTER USER — update postgres password manually if auth fails"
fi

echo "==> Renewing Let's Encrypt certificate (best effort)"
if command -v certbot >/dev/null 2>&1; then
  certbot renew --quiet --no-random-sleep-on-renew 2>/dev/null || true
  if [[ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    echo "==> Obtaining cert for ${DOMAIN}"
    certbot certonly --standalone --non-interactive --agree-tos \
      -m "admin@${DOMAIN}" -d "${DOMAIN}" 2>/dev/null || \
      echo "WARN: certbot certonly failed — ensure DNS resolves ${DOMAIN} to this host"
  fi
fi

echo "==> Recreating stack with new secrets + TLS nginx"
docker compose up -d --build postgres redis backend nginx
docker compose --profile monitoring up -d monitoring camera_probe viseron 2>/dev/null || true

echo "==> Waiting for health"
for i in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if curl -fsSk "https://127.0.0.1/health" >/dev/null 2>&1; then
  echo "    HTTPS health OK"
else
  echo "WARN: HTTPS health check failed — verify nginx certs mount and port 443"
fi

curl -sS "http://127.0.0.1/health" | head -c 200 || true
echo
docker compose ps nginx backend postgres redis
echo "==> Rotation complete. Invalidate active JWT sessions (users must re-login)."
echo "==> Rotate external API keys manually — see docs/SECRETS_ROTATION.md"
