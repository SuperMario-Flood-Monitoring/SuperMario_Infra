#!/usr/bin/env bash
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-/home/seoktae/Documents/TEAM_SUPERMARIO}"

sudo apt-get update
sudo apt-get install -y ca-certificates curl git rsync

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sudo sh
fi

sudo usermod -aG docker "$USER"
mkdir -p "$DEPLOY_PATH"

echo "Server initialized at ${DEPLOY_PATH}"
echo "If Docker was newly installed or group membership changed, log out and back in once."

