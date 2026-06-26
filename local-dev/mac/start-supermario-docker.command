#!/usr/bin/env sh
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

cat <<'EOF'
SuperMario Docker local launcher

Choose run mode:
  1) localhost mode
     - Open on this Mac: http://localhost:5173

  2) IP mode
     - Detect this Mac's Wi-Fi/LAN IP
     - Open on phone using: http://<detected-ip>:5173

EOF

printf 'Select mode [1/2] (default: 1): '
IFS= read -r MODE_CHOICE

case "${MODE_CHOICE:-1}" in
  1)
    HOST_MODE=localhost
    ;;
  2)
    HOST_MODE=ip
    ;;
  *)
    printf 'Unknown choice: %s\n' "$MODE_CHOICE" >&2
    printf '\nPress Enter to close this window...'
    IFS= read -r _
    exit 2
    ;;
esac

"$SCRIPT_DIR/start-supermario-docker-mac.sh" "$HOST_MODE" up
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  cat <<'EOF'

Docker start failed.

If the log contains "failed to fetch oauth token" or "401 Unauthorized",
Docker Desktop cannot currently pull public images from Docker Hub.

Try:
  docker logout
  docker login

Then run this file again.
EOF
fi

printf '\nPress Enter to close this window...'
IFS= read -r _
exit "$STATUS"
