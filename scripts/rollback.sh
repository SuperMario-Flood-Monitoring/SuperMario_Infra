#!/usr/bin/env bash
set -euo pipefail

SERVICE="${1:?usage: scripts/rollback.sh <frontend|backend|llm>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

if [ ! -f runtime/active-colors.env ]; then
  echo "No active color state found." >&2
  exit 1
fi

set -a
. runtime/active-colors.env
set +a

upsert_env() {
  local file="$1"
  local key="$2"
  local value="$3"
  if grep -q "^${key}=" "$file"; then
    sed -i.bak "s|^${key}=.*|${key}=${value}|" "$file"
    rm -f "${file}.bak"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

case "$SERVICE" in
  frontend)
    ACTIVE="${FRONTEND_ACTIVE:-blue}"
    ACTIVE_KEY="FRONTEND_ACTIVE"
    ;;
  backend)
    ACTIVE="${BACKEND_ACTIVE:-blue}"
    ACTIVE_KEY="BACKEND_ACTIVE"
    ;;
  llm)
    ACTIVE="${LLM_ACTIVE:-blue}"
    ACTIVE_KEY="LLM_ACTIVE"
    ;;
  *)
    echo "Unsupported service: $SERVICE" >&2
    exit 1
    ;;
esac

if [ "$ACTIVE" = "blue" ]; then
  TARGET="green"
else
  TARGET="blue"
fi

echo "Rolling back ${SERVICE}: ${ACTIVE} -> ${TARGET}"
scripts/healthcheck.sh "$SERVICE" "$TARGET"
upsert_env runtime/active-colors.env "$ACTIVE_KEY" "$TARGET"
scripts/render-nginx.sh "${NGINX_MODE:-https}"

docker compose -f docker-compose.prod.yml up -d nginx
docker compose -f docker-compose.prod.yml exec -T nginx nginx -s reload || docker compose -f docker-compose.prod.yml restart nginx

echo "Rollback complete: ${SERVICE} is active on ${TARGET}"

