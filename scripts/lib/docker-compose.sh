#!/usr/bin/env bash

docker_compose() {
  local docker_cmd=(docker)
  local compose_cmd=()

  if ! "${docker_cmd[@]}" ps >/dev/null 2>&1; then
    if command -v sudo >/dev/null 2>&1 && sudo -n docker ps >/dev/null 2>&1; then
      docker_cmd=(sudo -n docker)
    else
      echo "Docker daemon is not reachable by the current user." >&2
      echo "Add the deploy user to the docker group, reconnect SSH, or allow passwordless sudo for docker." >&2
      exit 126
    fi
  fi

  if "${docker_cmd[@]}" compose version >/dev/null 2>&1; then
    compose_cmd=("${docker_cmd[@]}" compose)
  elif command -v docker-compose >/dev/null 2>&1; then
    if [ "${docker_cmd[0]}" = "sudo" ]; then
      compose_cmd=(sudo -n docker-compose)
    else
      compose_cmd=(docker-compose)
    fi
  else
    echo "Docker Compose is required. Install the Docker Compose v2 plugin or docker-compose." >&2
    exit 127
  fi

  "${compose_cmd[@]}" "$@"
}
