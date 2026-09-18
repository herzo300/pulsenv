#!/usr/bin/env bash
# Generate self-signed TLS certs for optional HTTPS nginx overlay.
set -eu -o pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CERT_DIR="${ROOT}/certs"
mkdir -p "${CERT_DIR}"
openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
  -keyout "${CERT_DIR}/privkey.pem" \
  -out "${CERT_DIR}/fullchain.pem" \
  -subj "/CN=soobshio.local"
echo "Created ${CERT_DIR}/fullchain.pem and privkey.pem"
echo "For HTTPS: use ops/timeweb/nginx-https.conf.example and mount ./certs in compose."
