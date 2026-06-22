#!/usr/bin/env bash

docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
    return
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
    return
  fi

  echo "Docker Compose is required. Install the Docker Compose v2 plugin or docker-compose." >&2
  exit 127
}
