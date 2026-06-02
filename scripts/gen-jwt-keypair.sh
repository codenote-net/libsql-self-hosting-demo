#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JWT_DIR="${ROOT_DIR}/.local/jwt"
PRIVATE_KEY="${JWT_DIR}/jwt.key"
PUBLIC_KEY="${JWT_DIR}/jwt.pub"

mkdir -p "${JWT_DIR}"

if [[ -f "${PRIVATE_KEY}" && -f "${PUBLIC_KEY}" ]]; then
  echo "JWT key pair already exists in ${JWT_DIR}"
  exit 0
fi

if [[ -f "${PRIVATE_KEY}" || -f "${PUBLIC_KEY}" ]]; then
  echo "Refusing to overwrite partial JWT key state in ${JWT_DIR}" >&2
  exit 1
fi

openssl genpkey -algorithm Ed25519 -out "${PRIVATE_KEY}"
openssl pkey -in "${PRIVATE_KEY}" -pubout -out "${PUBLIC_KEY}"
chmod 600 "${PRIVATE_KEY}"
chmod 644 "${PUBLIC_KEY}"

echo "Generated local JWT key pair in ${JWT_DIR}"
