#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JWT_DIR="${ROOT_DIR}/.local/jwt"
PRIVATE_KEY="${JWT_DIR}/jwt.key"
TOKEN_FILE="${JWT_DIR}/jwt.token"

if [[ ! -f "${PRIVATE_KEY}" ]]; then
  "${ROOT_DIR}/scripts/gen-jwt-keypair.sh"
fi

if ! command -v mise >/dev/null 2>&1; then
  echo "Missing required command: mise" >&2
  exit 1
fi

mise exec -- node "${ROOT_DIR}/scripts/sign-jwt.mjs" "${PRIVATE_KEY}" "${TOKEN_FILE}"
chmod 600 "${TOKEN_FILE}"
echo "Generated local JWT token at ${TOKEN_FILE}"
