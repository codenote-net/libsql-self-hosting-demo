# Implementation Notes

## Runtime

The demo uses `ghcr.io/tursodatabase/libsql-server:v0.24.32`, pinned to the
amd64 manifest digest:

```text
sha256:528e068844b4bc5b87fb128da87e98d361d3414c4e1cced7b943939248e0ed2f
```

The image entrypoint derives core server flags from environment variables. The
Compose file sets:

- `SQLD_DB_PATH`
- `SQLD_HTTP_LISTEN_ADDR`
- `SQLD_GRPC_LISTEN_ADDR` only on the primary
- `SQLD_PRIMARY_URL` only on the replica

The Admin API key is passed explicitly with `--admin-auth-key` because the
verified image accepts `Authorization: basic <key>` for Admin API calls.

## JWT Generation

Generate the Ed25519 key pair:

```sh
./scripts/gen-jwt-keypair.sh
```

Outputs:

```text
.local/jwt/jwt.key
.local/jwt/jwt.pub
```

Generate the JWT token:

```sh
./scripts/gen-auth-token.sh
```

Output:

```text
.local/jwt/jwt.token
```

The token is signed by `scripts/sign-jwt.mjs` with this local development
payload:

```json
{ "a": "rw" }
```

The script also adds `iat` and a one-day `exp`. These artifacts are local-only
and not production-ready.

## Certificates

The default demo uses plaintext h2c gRPC replication. TLS files are generated
for the optional `docker-compose.tls.yml` appendix:

```sh
./scripts/gen-certs.sh
```

Outputs:

```text
.local/certs/ca_cert.pem
.local/certs/ca_key.pem
.local/certs/server_cert.pem
.local/certs/server_key.pem
.local/certs/client_cert.pem
.local/certs/client_key.pem
```

The certificates are self-signed, short-lived, and development-only.

## Smoke Test Scenarios

`./scripts/smoke-test.sh` verifies:

1. Default namespace replication: primary write, replica read.
2. Primary-only namespaces: Admin API namespace creation, auth success, invalid
   token failure, and nonexistent namespace failure.
3. Namespace plus replica re-verification: create a namespace, write through the
   primary, and read through the replica.

On 2026-06-02 with libSQL server `v0.24.32`, scenario 3 succeeded locally:

```text
Namespace replica read succeeded: 1
```

The script keeps this scenario configurable with `EXPECT_NAMESPACE_REPLICA`.
Set `EXPECT_NAMESPACE_REPLICA=pass` if future verification should fail when the
namespace replica read does not work.

## Verification Log

Commands run locally during implementation:

```sh
mise install
mise exec -- pnpm --dir app install --frozen-lockfile
mise exec -- pnpm --dir app check
mise exec -- pnpm --dir app check:format
mise exec -- shellcheck scripts/*.sh
mise exec -- gitleaks detect --source . --no-git --redact
docker compose config
docker compose -f docker-compose.yml -f docker-compose.namespaced.yml config
docker compose -f docker-compose.yml -f docker-compose.tls.yml config
mise exec -- ./scripts/smoke-test.sh
```

All listed commands passed before the documentation commit.
