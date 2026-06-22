#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
. scripts/lib/docker-compose.sh

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

DOMAIN="${DOMAIN:-supermario.o-r.kr}"

docker_compose -f docker-compose.prod.yml run --rm --entrypoint sh certbot \
  -c "test -f '/etc/letsencrypt/live/${DOMAIN}/fullchain.pem' && test -f '/etc/letsencrypt/live/${DOMAIN}/privkey.pem'" \
  >/dev/null 2>&1
