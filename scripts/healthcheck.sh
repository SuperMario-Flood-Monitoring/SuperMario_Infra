#!/usr/bin/env bash
set -euo pipefail

SERVICE="${1:?usage: scripts/healthcheck.sh <frontend|backend|llm> <blue|green>}"
COLOR="${2:?usage: scripts/healthcheck.sh <frontend|backend|llm> <blue|green>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
. scripts/lib/docker-compose.sh

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

if [ -f runtime/image-tags.env ]; then
  set -a
  . runtime/image-tags.env
  set +a
fi

CONTAINER_SERVICE="${SERVICE}-${COLOR}"
MAX_RETRIES="${MAX_HEALTH_RETRIES:-30}"
SLEEP_SECONDS="${HEALTH_RETRY_SECONDS:-2}"

case "$SERVICE" in
  frontend)
    CHECK_CMD='wget -qO- http://127.0.0.1/ >/dev/null'
    ;;
  backend)
    CHECK_CMD='python -c "import urllib.request; urllib.request.urlopen(\"http://127.0.0.1:8000/api/engine/health\", timeout=5).read()"'
    ;;
  llm)
    CHECK_CMD='python -c "import os, urllib.request; p=os.getenv(\"LLM_API_PREFIX\", \"/llm\").strip() or \"/llm\"; p=\"/\" + p.lstrip(\"/\"); p=p.rstrip(\"/\"); urllib.request.urlopen(\"http://127.0.0.1:8000\" + p + \"/health\", timeout=5).read()"'
    ;;
  *)
    echo "Unsupported service: $SERVICE" >&2
    exit 1
    ;;
esac

for attempt in $(seq 1 "$MAX_RETRIES"); do
  if docker_compose -f docker-compose.prod.yml exec -T "$CONTAINER_SERVICE" sh -lc "$CHECK_CMD" >/dev/null 2>&1; then
    echo "${CONTAINER_SERVICE} health check passed"
    exit 0
  fi

  echo "${CONTAINER_SERVICE} not healthy yet (${attempt}/${MAX_RETRIES})"
  sleep "$SLEEP_SECONDS"
done

echo "${CONTAINER_SERVICE} health check failed" >&2
exit 1
