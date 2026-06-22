#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.example to .env and fill DOMAIN and LETSENCRYPT_EMAIL first." >&2
  exit 1
fi

set -a
. ./.env
set +a

if [ -z "${DOMAIN:-}" ] || [ -z "${LETSENCRYPT_EMAIL:-}" ]; then
  echo "DOMAIN and LETSENCRYPT_EMAIL are required." >&2
  exit 1
fi

scripts/render-nginx.sh http
docker compose -f docker-compose.prod.yml up -d nginx

STAGING_ARGS=()
if [ "${LETSENCRYPT_STAGING:-false}" = "true" ]; then
  STAGING_ARGS=(--staging)
fi

docker compose -f docker-compose.prod.yml run --rm --entrypoint certbot certbot \
  certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  --domain "$DOMAIN" \
  --email "$LETSENCRYPT_EMAIL" \
  --agree-tos \
  --no-eff-email \
  "${STAGING_ARGS[@]}"

scripts/render-nginx.sh https
docker compose -f docker-compose.prod.yml up -d nginx certbot
docker compose -f docker-compose.prod.yml exec -T nginx nginx -s reload || docker compose -f docker-compose.prod.yml restart nginx

echo "Let's Encrypt certificate initialized for ${DOMAIN}"

