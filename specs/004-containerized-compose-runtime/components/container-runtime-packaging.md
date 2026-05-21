# Spec Kit Component: container-runtime-packaging

## Role

Define container build/run packaging for the full TraderX baseline component set in state `004`.

## Scope

- `database`
- `reference-data`
- `trade-feed`
- `people-service`
- `account-service`
- `position-service`
- `trade-processor`
- `trade-service`
- `web-front-end-angular`
- `ingress` (NGINX)

## Requirements

- Every component must have a generated `Dockerfile.compose`.
- Compose wiring must come from `system/docker-compose.spec.yaml`.
- NGINX ingress routes must be sourced from `system/ingress-nginx.conf.template`.
- Runtime must preserve baseline flow compatibility through ingress entrypoint.
- Frontend container runtime packaging for deployed/demo targets must serve production/static assets and must not expose Vite/Angular dev-server hot-reload endpoints (for example `@vite/client` or `/@fs/*`).
- Containerized compose artifacts must not hardcode localhost-only CORS origins; generated runtime/deploy flows must derive default CORS allowlists from `TRADERX_FQDN` (with explicit `CORS_ALLOWED_ORIGINS` override support).
- API explorer packaging for state `004` must exclude Pub/Sub inspector assets/UI; Pub/Sub inspector packaging is reserved for later NATS-enabled states.
- Deployment-bundle external reverse-proxy snippets must include websocket upgrade route mappings required by active runtime messaging paths and must be generated from the active ingress transport contract for the emitted state (for example `/nats-ws` for NATS states, Socket.IO routes only where still active).
- Deployment bundles for `aws-ec2-compose` must include host prerequisite scripts (`host-setup-check.sh`, `host-setup-install.sh`) and default clone instructions that do not require token-authenticated Git URLs for public generated-state branches.

## Generation Surface

- `pipeline/generate-state-004-containerized-compose-runtime.sh`
- `specs/004-containerized-compose-runtime/generation/patches/*.patch`
- `scripts/start-state-004-containerized-generated.sh`
- `scripts/stop-state-004-containerized-generated.sh`
- `scripts/status-state-004-containerized-generated.sh`
- `scripts/test-state-004-containerized.sh`

Runtime start modes:

- default build + start: `./scripts/start-state-004-containerized-generated.sh`
- restart without image rebuild: `./scripts/start-state-004-containerized-generated.sh --skip-build`
