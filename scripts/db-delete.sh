#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-}"
if [[ -z "${NAMESPACE}" ]]; then
  echo "Usage: scripts/db-delete.sh <namespace>" >&2
  exit 1
fi

ADMIN_PORT="${PRIMARY_ADMIN_PORT:-18082}"
ADMIN_KEY="${LIBSQL_ADMIN_AUTH_KEY:-local-admin-key}"

curl --fail-with-body --silent --show-error \
  -X DELETE "http://127.0.0.1:${ADMIN_PORT}/v1/namespaces/${NAMESPACE}" \
  -H "Authorization: basic ${ADMIN_KEY}"
echo
