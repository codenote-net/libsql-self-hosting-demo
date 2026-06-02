#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker compose -f "${ROOT_DIR}/docker-compose.yml" -f "${ROOT_DIR}/docker-compose.namespaced.yml" down -v --remove-orphans
docker compose -f "${ROOT_DIR}/docker-compose.yml" down -v --remove-orphans
rm -rf "${ROOT_DIR}/.local"

echo "Removed Docker services, volumes, and generated local state."
