#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOCAL_DEV_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
INFRA_DIR=$(CDPATH= cd -- "$LOCAL_DEV_DIR/.." && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$INFRA_DIR/.." && pwd)
COMPOSE_FILE="$LOCAL_DEV_DIR/docker-compose.local.yml"
LOCAL_COMPOSE_ENV_FILE="$LOCAL_DEV_DIR/local-dev.compose.env"
LLM_ENV_FILE="$PROJECT_ROOT/SuperMario_LLM/.env"
LLM_ENV_EXAMPLE="$PROJECT_ROOT/SuperMario_LLM/.env.example"

print_usage() {
  cat <<'EOF'
Usage:
  ./start-supermario-docker-mac.sh [host-mode] [command]

Host modes:
  localhost  Use localhost URLs. Default.
  ip         Detect this Mac's LAN IP and expose URLs for phone testing.

Commands:
  up          Build and start all local services in the background. Default.
  start       Same as up.
  foreground  Build and start all local services in the foreground.
  logs        Follow logs.
  ps          Show container status.
  stop        Stop containers without removing them.
  down        Stop and remove containers.
  rebuild     Rebuild and recreate containers.

Local URLs:
  React:   http://localhost:5173
  Django:  http://localhost:8000/api/engine/health
  LLM:     http://localhost:8001/llm/health

Examples:
  ./mac/start-supermario-docker-mac.sh localhost up
  ./mac/start-supermario-docker-mac.sh ip up
EOF
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

print_dockerhub_auth_help() {
  cat >&2 <<'EOF'

Docker Hub image pull failed.

If the error says "failed to fetch oauth token" or "401 Unauthorized",
refresh Docker Desktop's Docker Hub credentials:

  docker logout
  docker login

Then rerun:

  ./mac/start-supermario-docker-mac.sh up

EOF
}

detect_lan_ip() {
  local interface ip

  interface=$(route get 8.8.8.8 2>/dev/null | awk '/interface:/{print $2; exit}') || true
  if [ -n "${interface:-}" ]; then
    ip=$(ipconfig getifaddr "$interface" 2>/dev/null || true)
    if [ -n "${ip:-}" ]; then
      printf '%s\n' "$ip"
      return 0
    fi
  fi

  ip=$(ipconfig getifaddr en0 2>/dev/null || true)
  if [ -n "${ip:-}" ]; then
    printf '%s\n' "$ip"
    return 0
  fi

  ip=$(ipconfig getifaddr en1 2>/dev/null || true)
  if [ -n "${ip:-}" ]; then
    printf '%s\n' "$ip"
    return 0
  fi

  return 1
}

require_dir() {
  local path label
  path=$1
  label=$2

  [ -d "$path" ] || die "Missing $label directory: $path"
}

cd "$LOCAL_DEV_DIR"

[ -f "$COMPOSE_FILE" ] || die "Missing compose file: $COMPOSE_FILE"
require_dir "$PROJECT_ROOT/SuperMario_Django/backend" "Django backend"
require_dir "$PROJECT_ROOT/SuperMario_React" "React frontend"
require_dir "$PROJECT_ROOT/SuperMario_LLM" "LLM server"

if [ ! -f "$LOCAL_COMPOSE_ENV_FILE" ]; then
  : > "$LOCAL_COMPOSE_ENV_FILE"
fi

if ! command -v docker >/dev/null 2>&1; then
  die "Docker is not installed. Install Docker Desktop first."
fi

if ! docker info >/dev/null 2>&1; then
  die "Docker is not running. Start Docker Desktop and try again."
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  die "Docker Compose is not available. Install or update Docker Desktop."
fi

if [ ! -f "$LLM_ENV_FILE" ]; then
  if [ -f "$LLM_ENV_EXAMPLE" ]; then
    cp "$LLM_ENV_EXAMPLE" "$LLM_ENV_FILE"
    printf 'Created %s from .env.example. Fill API keys if LLM calls need them.\n' "$LLM_ENV_FILE"
  else
    cat > "$LLM_ENV_FILE" <<'EOF'
APP_ENV=local
LLM_API_PREFIX=/llm
OPENAI_API_KEY=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
EOF
    printf 'Created default %s. Fill API keys if LLM calls need them.\n' "$LLM_ENV_FILE"
  fi
fi

HOST_MODE=${SUPERMARIO_HOST_MODE:-localhost}
COMMAND=${1:-up}

case "${1:-}" in
  localhost|ip)
    HOST_MODE=$1
    COMMAND=${2:-up}
    ;;
esac

case "$HOST_MODE" in
  localhost)
    export LOCAL_DEV_HOST_IP=localhost
    ;;
  ip)
    LOCAL_IP=$(detect_lan_ip) || die "Could not detect this Mac's LAN IP. Check Wi-Fi/network connection."
    export LOCAL_DEV_HOST_IP="$LOCAL_IP"
    ;;
  *)
    die "Unknown host mode: $HOST_MODE. Use localhost or ip."
    ;;
esac

REACT_URL="http://${LOCAL_DEV_HOST_IP}:5173"
DJANGO_HEALTH_URL="http://${LOCAL_DEV_HOST_IP}:8000/api/engine/health"
LLM_HEALTH_URL="http://${LOCAL_DEV_HOST_IP}:8001/llm/health"

case "$COMMAND" in
  up|start)
    if ! $COMPOSE --env-file "$LOCAL_COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" up --build -d; then
      print_dockerhub_auth_help
      exit 1
    fi
    $COMPOSE --env-file "$LOCAL_COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" ps
    cat <<EOF

SuperMario local stack is starting.

Mode:
  Host:    ${HOST_MODE}

Open:
  React:   ${REACT_URL}
  Django:  ${DJANGO_HEALTH_URL}
  LLM:     ${LLM_HEALTH_URL}

Follow logs:
  ./mac/start-supermario-docker-mac.sh logs
EOF
    ;;
  foreground)
    if ! $COMPOSE --env-file "$LOCAL_COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" up --build; then
      print_dockerhub_auth_help
      exit 1
    fi
    ;;
  logs)
    $COMPOSE --env-file "$LOCAL_COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" logs -f
    ;;
  ps|status)
    $COMPOSE --env-file "$LOCAL_COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" ps
    ;;
  stop)
    $COMPOSE --env-file "$LOCAL_COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" stop
    ;;
  down)
    $COMPOSE --env-file "$LOCAL_COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" down
    ;;
  rebuild)
    if ! $COMPOSE --env-file "$LOCAL_COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" up --build --force-recreate -d; then
      print_dockerhub_auth_help
      exit 1
    fi
    $COMPOSE --env-file "$LOCAL_COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" ps
    ;;
  -h|--help|help)
    print_usage
    ;;
  *)
    print_usage
    exit 2
    ;;
esac
