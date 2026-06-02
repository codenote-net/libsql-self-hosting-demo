#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/app"
TOKEN_PATH="${ROOT_DIR}/.local/jwt/jwt.token"
PRIMARY_HTTP_PORT="${PRIMARY_HTTP_PORT:-18080}"
REPLICA_HTTP_PORT="${REPLICA_HTTP_PORT:-18083}"
PRIMARY_ADMIN_PORT="${PRIMARY_ADMIN_PORT:-18082}"
ADMIN_KEY="${LIBSQL_ADMIN_AUTH_KEY:-local-admin-key}"
EXPECT_NAMESPACE_REPLICA="${EXPECT_NAMESPACE_REPLICA:-known-limitation}"
LIBSQL_IMAGE="${LIBSQL_IMAGE:-ghcr.io/tursodatabase/libsql-server@sha256:528e068844b4bc5b87fb128da87e98d361d3414c4e1cced7b943939248e0ed2f}"
LIBSQL_PLATFORM="${LIBSQL_PLATFORM:-linux/amd64}"

log() {
  printf '\n==> %s\n' "$1"
}

compose_base() {
  docker compose -f "${ROOT_DIR}/docker-compose.yml" "$@"
}

compose_namespaced() {
  docker compose -f "${ROOT_DIR}/docker-compose.yml" -f "${ROOT_DIR}/docker-compose.namespaced.yml" "$@"
}

wait_http() {
  local url="$1"
  local name="$2"
  for _ in $(seq 1 60); do
    local status
    status="$(curl --silent --output /dev/null --write-out '%{http_code}' "${url}" || true)"
    if [[ "${status}" != "000" ]]; then
      echo "${name} is reachable"
      return 0
    fi
    sleep 1
  done
  echo "${name} did not become reachable at ${url}" >&2
  return 1
}

run_cli() {
  pnpm --dir "${APP_DIR}" exec tsx src/index.ts "$@" --token-path "${TOKEN_PATH}"
}

poll_replica_count() {
  local expected="$1"
  for _ in $(seq 1 30); do
    local count
    count="$(run_cli count --target replica 2>/dev/null || true)"
    if [[ "${count}" == "${expected}" ]]; then
      echo "Replica reached count ${expected}"
      return 0
    fi
    sleep 1
  done
  echo "Replica did not reach count ${expected}" >&2
  return 1
}

create_namespace() {
  local namespace="$1"
  curl --fail-with-body --silent --show-error \
    -X POST "http://127.0.0.1:${PRIMARY_ADMIN_PORT}/v1/namespaces/${namespace}/create" \
    -H "Authorization: basic ${ADMIN_KEY}" \
    -H "Content-Type: application/json" \
    --data '{}' >/dev/null
}

cleanup_containers() {
  compose_namespaced down -v --remove-orphans >/dev/null 2>&1 || true
  compose_base down -v --remove-orphans >/dev/null 2>&1 || true
}

reset_data_dir() {
  mkdir -p "${ROOT_DIR}/.local/data"
  docker run --rm --platform "${LIBSQL_PLATFORM}" --entrypoint /bin/sh \
    -v "${ROOT_DIR}/.local/data:/data" "${LIBSQL_IMAGE}" \
    -c 'rm -rf /data/*'
  mkdir -p "${ROOT_DIR}/.local/data/primary" "${ROOT_DIR}/.local/data/replica"
}

trap cleanup_containers EXIT

log "Preparing local state"
"${ROOT_DIR}/scripts/setup.sh"

log "Scenario 1: default namespace replication"
cleanup_containers
reset_data_dir
compose_base up -d
wait_http "http://127.0.0.1:${PRIMARY_HTTP_PORT}" "primary HTTP"
wait_http "http://127.0.0.1:${REPLICA_HTTP_PORT}" "replica HTTP"
run_cli init --target primary
run_cli insert --target primary --label "default-replication"
poll_replica_count "1"

log "Scenario 2: primary-only namespaces"
cleanup_containers
reset_data_dir
compose_namespaced up -d primary
wait_http "http://127.0.0.1:${PRIMARY_HTTP_PORT}" "namespaced primary HTTP"
create_namespace "demo"
run_cli init --target primary --namespace demo
run_cli insert --target primary --namespace demo --label "namespaced-primary"
run_cli auth-check --target primary --namespace demo
if run_cli auth-check --target primary --namespace demo --token "invalid.jwt.token" >/dev/null 2>&1; then
  echo "Invalid token unexpectedly succeeded" >&2
  exit 1
fi
if run_cli count --target primary --namespace missing >/dev/null 2>&1; then
  echo "Missing namespace unexpectedly succeeded" >&2
  exit 1
fi
echo "Auth failure and missing namespace failure were verified"

log "Scenario 3: namespace plus replica re-verification"
cleanup_containers
reset_data_dir
compose_namespaced up -d
wait_http "http://127.0.0.1:${PRIMARY_HTTP_PORT}" "namespaced primary HTTP"
wait_http "http://127.0.0.1:${REPLICA_HTTP_PORT}" "namespaced replica HTTP"
create_namespace "tenant"
run_cli init --target primary --namespace tenant
run_cli insert --target primary --namespace tenant --label "namespace-replica-check"
if run_cli count --target replica --namespace tenant >/tmp/libsql-namespace-replica.out 2>/tmp/libsql-namespace-replica.err; then
  echo "Namespace replica read succeeded: $(cat /tmp/libsql-namespace-replica.out)"
else
  echo "Namespace replica read did not succeed; this is expected for upstream issue #1804."
  sed -n '1,5p' /tmp/libsql-namespace-replica.err
  if [[ "${EXPECT_NAMESPACE_REPLICA}" == "pass" ]]; then
    exit 1
  fi
fi

log "Cleanup and rerun behavior"
cleanup_containers
"${ROOT_DIR}/scripts/cleanup.sh"
"${ROOT_DIR}/scripts/setup.sh"
echo "Smoke test passed"
