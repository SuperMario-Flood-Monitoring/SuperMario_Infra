#!/usr/bin/env bash
set -euo pipefail

SERVICE="${1:?usage: scripts/deploy.sh <frontend|backend|llm> <image> <tag>}"
IMAGE="${2:?usage: scripts/deploy.sh <frontend|backend|llm> <image> <tag>}"
TAG="${3:?usage: scripts/deploy.sh <frontend|backend|llm> <image> <tag>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
. scripts/lib/docker-compose.sh

if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.example to .env and fill production values first." >&2
  exit 1
fi

mkdir -p runtime nginx/conf.d

set -a
. ./.env
set +a

if [ -f runtime/image-tags.env ]; then
  set -a
  . runtime/image-tags.env
  set +a
fi

if [ ! -f runtime/active-colors.env ]; then
  cat > runtime/active-colors.env <<'EOF'
FRONTEND_ACTIVE=blue
BACKEND_ACTIVE=blue
LLM_ACTIVE=blue
EOF
fi

set -a
. runtime/active-colors.env
set +a

upsert_env() {
  local file="$1"
  local key="$2"
  local value="$3"
  touch "$file"
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
    IMAGE_KEY_PREFIX="FRONTEND"
    ACTIVE_KEY="FRONTEND_ACTIVE"
    ;;
  backend)
    ACTIVE="${BACKEND_ACTIVE:-blue}"
    IMAGE_KEY_PREFIX="BACKEND"
    ACTIVE_KEY="BACKEND_ACTIVE"
    ;;
  llm)
    ACTIVE="${LLM_ACTIVE:-blue}"
    IMAGE_KEY_PREFIX="LLM"
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

TARGET_UPPER="$(printf '%s' "$TARGET" | tr '[:lower:]' '[:upper:]')"
IMAGE_KEY="${IMAGE_KEY_PREFIX}_${TARGET_UPPER}_IMAGE"
FULL_IMAGE="${IMAGE}:${TAG}"

echo "Deploying ${SERVICE} to ${TARGET}: ${FULL_IMAGE}"
upsert_env runtime/image-tags.env "$IMAGE_KEY" "$FULL_IMAGE"

set -a
. runtime/image-tags.env
set +a

TARGET_SERVICE="${SERVICE}-${TARGET}"

docker_compose -f docker-compose.prod.yml pull "$TARGET_SERVICE"
docker_compose -f docker-compose.prod.yml up -d postgres redis "$TARGET_SERVICE"

scripts/healthcheck.sh "$SERVICE" "$TARGET"

upsert_env runtime/active-colors.env "$ACTIVE_KEY" "$TARGET"
scripts/render-nginx.sh "${NGINX_MODE:-https}"

docker_compose -f docker-compose.prod.yml up -d nginx certbot
if ! docker_compose -f docker-compose.prod.yml exec -T nginx nginx -s reload; then
  docker_compose -f docker-compose.prod.yml restart nginx
fi

if [ "${STOP_OLD_AFTER_DEPLOY:-false}" = "true" ]; then
  docker_compose -f docker-compose.prod.yml stop "${SERVICE}-${ACTIVE}" || true
fi

echo "Deployment complete: ${SERVICE} is active on ${TARGET}"
