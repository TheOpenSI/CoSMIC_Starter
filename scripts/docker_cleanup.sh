#!/usr/bin/env bash
# Comprehensive docker cleanup: containers, volumes, networks, images, then prune.

docker_cleanup() {
  header "Docker Cleanup"

  if ask_yn "Stop all running containers?" "y"; then
    info "Stopping running containers..."
    docker ps -q | xargs -r docker stop
  fi

  info "Removing containers..."
  docker ps -aq | xargs -r docker rm -f

  info "Removing volumes..."
  docker volume ls -q | xargs -r docker volume rm -f

  info "Removing custom networks..."
  docker network ls --filter type=custom -q | xargs -r docker network rm

  info "Removing images..."
  docker images -aq | xargs -r docker rmi -f

  info "Running system prune..."
  docker system prune -af --volumes

  header "Docker disk usage"
  docker system df
}
