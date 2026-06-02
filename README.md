# libsql-self-hosting-demo

Reproducible local demo for self-hosting libSQL with a primary server, a
replica server, JWT auth, namespaces, and a TypeScript CLI.

License: MIT

## Requirements

- Docker with Docker Compose
- `mise`
- Rosetta emulation on Apple Silicon when running the pinned `linux/amd64`
  image locally

This repository does not rely on globally installed Node.js, pnpm, gitleaks,
lefthook, or shellcheck. Those tools are pinned in `.mise.toml`.

## Quick Start

```sh
mise install
lefthook install
pnpm --dir app install --frozen-lockfile
./scripts/setup.sh
docker compose up -d
./scripts/smoke-test.sh
```

Clean up all containers, volumes, and generated local state:

```sh
./scripts/cleanup.sh
```

## What It Demonstrates

- Primary writes and replica reads on the default namespace.
- JWT-authenticated libSQL HTTP access with generated local Ed25519 keys.
- Admin API namespace creation and deletion.
- Primary-only namespace access, auth failure, and nonexistent namespace failure.
- Namespace plus replica re-verification. With the pinned image used here,
  namespaced replica reads succeeded during local verification.
- Cleanup and re-run behavior from generated local state.

## Commands

```sh
./scripts/setup.sh
./scripts/db-create.sh demo
./scripts/db-delete.sh demo
./scripts/smoke-test.sh
./scripts/cleanup.sh
pnpm --dir app demo
pnpm --dir app start -- init --target primary
pnpm --dir app start -- insert --target primary --label hello
pnpm --dir app start -- read --target replica
```

The CLI reads `.local/jwt/jwt.token` by default through the smoke test. For
manual commands, pass an explicit token path when needed:

```sh
pnpm --dir app start -- count --target primary --token-path ../.local/jwt/jwt.token
```

## Ports

All host ports bind to `127.0.0.1` and can be changed through `.env`.

| Service | Purpose | Default |
| --- | --- | --- |
| primary | HTTP API | `127.0.0.1:18080` |
| primary | gRPC replication | `127.0.0.1:18081` |
| primary | Admin API | `127.0.0.1:18082` |
| replica | HTTP API | `127.0.0.1:18083` |

## Generated Files

`./scripts/setup.sh` creates local-only development artifacts:

```text
.local/
  certs/
  data/
  jwt/
    jwt.key
    jwt.pub
    jwt.token
```

Generated private keys, JWT tokens, certificates, database files, and runtime
state are ignored by Git and must not be committed. They are not production
secrets and are only suitable for this local demo.

## Verified Environment

- Date: 2026-06-02
- Host architecture: `arm64`
- Docker server: `29.4.2`
- libSQL server image: `ghcr.io/tursodatabase/libsql-server:v0.24.32`
- Pinned amd64 digest:
  `sha256:528e068844b4bc5b87fb128da87e98d361d3414c4e1cced7b943939248e0ed2f`
- Native arm64 image digest was not used; local Apple Silicon verification ran
  the pinned amd64 image with `platform: linux/amd64`.
- Node.js: `26.3.0`
- pnpm: `11.5.1`
- gitleaks: `8.30.1`
- lefthook: `2.1.9`
- shellcheck: `0.11.0`
- `@libsql/client`: `0.17.3`
- `@biomejs/biome`: `2.4.14`
- TypeScript: `6.0.3`
- tsx: `4.22.4`

## Troubleshooting

If Docker ports are already in use, copy `.env.example` to `.env` and change
the host ports.

If `<namespace>.localhost` does not resolve in your environment, use a resolver
that maps localhost subdomains to `127.0.0.1`; macOS and most modern browsers
already do this.

If replica reads lag, rerun `./scripts/smoke-test.sh`. The smoke test polls for
replica consistency instead of assuming immediate visibility.

If Admin API calls return `401`, check that Compose includes
`--admin-auth-key` and that scripts send `Authorization: basic local-admin-key`.

If JWT requests fail, regenerate local auth state:

```sh
rm -rf .local/jwt
./scripts/setup.sh
```

If a non-interactive shell reports
`ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY`, a corepack or global `pnpm` may be
resolving ahead of mise. The repository scripts call `mise exec -- pnpm` so they
use the pinned `pnpm 11.5.1`; run `mise install` first, then rerun
`./scripts/setup.sh` or `./scripts/smoke-test.sh`. For manual app commands,
prefer:

```sh
mise exec -- pnpm --dir app install --frozen-lockfile
mise exec -- pnpm --dir app start -- count --target primary --token-path ../.local/jwt/jwt.token
```

## References

- Reference article: https://virtala.dev/posts/libsql-self-hosting/
- libSQL repository: https://github.com/tursodatabase/libsql
- libSQL client package: https://www.npmjs.com/package/@libsql/client
- mise: https://mise.jdx.dev/
- Biome: https://biomejs.dev/
