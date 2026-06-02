#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need docker
need node
need openssl
need pnpm

mkdir -p "${ROOT_DIR}/.local/data/primary" \
  "${ROOT_DIR}/.local/data/replica" \
  "${ROOT_DIR}/.local/jwt" \
  "${ROOT_DIR}/.local/certs"

"${ROOT_DIR}/scripts/gen-jwt-keypair.sh"
"${ROOT_DIR}/scripts/gen-auth-token.sh"
"${ROOT_DIR}/scripts/gen-certs.sh"

if [[ ! -f "${ROOT_DIR}/app/pnpm-lock.yaml" ]]; then
  echo "Missing app/pnpm-lock.yaml. Run pnpm --dir app install first." >&2
  exit 1
fi

pnpm --dir "${ROOT_DIR}/app" install --frozen-lockfile

echo "Local setup is ready. Docker services were not started."
