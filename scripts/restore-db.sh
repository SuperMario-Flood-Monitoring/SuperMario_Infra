#!/usr/bin/env bash
set -euo pipefail

BACKUP_FILE="${1:?usage: scripts/restore-db.sh <backup.sql>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE" >&2
  exit 1
fi

cat "$BACKUP_FILE" | docker compose -f docker-compose.prod.yml exec -T postgres \
  psql -U "${POSTGRES_USER:-supermario}" "${POSTGRES_DB:-supermario}"

echo "Restored database backup: $BACKUP_FILE"

