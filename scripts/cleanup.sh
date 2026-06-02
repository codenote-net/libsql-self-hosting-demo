#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBSQL_IMAGE="${LIBSQL_IMAGE:-ghcr.io/tursodatabase/libsql-server@sha256:528e068844b4bc5b87fb128da87e98d361d3414c4e1cced7b943939248e0ed2f}"
LIBSQL_PLATFORM="${LIBSQL_PLATFORM:-linux/amd64}"

docker compose -f "${ROOT_DIR}/docker-compose.yml" -f "${ROOT_DIR}/docker-compose.namespaced.yml" down -v --remove-orphans
docker compose -f "${ROOT_DIR}/docker-compose.yml" down -v --remove-orphans

if [[ -d "${ROOT_DIR}/.local/data" ]]; then
  docker run --rm --platform "${LIBSQL_PLATFORM}" --entrypoint /bin/sh \
    -v "${ROOT_DIR}/.local/data:/data" "${LIBSQL_IMAGE}" \
    -c 'rm -rf /data/*'
fi

rm -rf "${ROOT_DIR}/.local"

echo "Removed Docker services, volumes, and generated local state."
