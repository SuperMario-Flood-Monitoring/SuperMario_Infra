#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${GHCR_REGISTRY:-ghcr.io}"
USERNAME="${GHCR_USERNAME:?GHCR_USERNAME is required}"
TOKEN="$(cat)"

if [ -z "$TOKEN" ]; then
  echo "GHCR token must be provided on stdin." >&2
  exit 1
fi

DOCKER_CMD=(docker)
if ! "${DOCKER_CMD[@]}" ps >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1 && sudo -n docker ps >/dev/null 2>&1; then
    DOCKER_CMD=(sudo -n docker)
  else
    echo "Docker daemon is not reachable by the current user." >&2
    echo "Add the deploy user to the docker group, reconnect SSH, or allow passwordless sudo for docker." >&2
    exit 126
  fi
fi

printf '%s' "$TOKEN" | "${DOCKER_CMD[@]}" login "$REGISTRY" -u "$USERNAME" --password-stdin >/dev/null
echo "Logged in to ${REGISTRY} as ${USERNAME}"
