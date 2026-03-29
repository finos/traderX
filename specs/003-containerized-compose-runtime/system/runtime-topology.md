# Runtime Topology (State 003)

State `003-containerized-compose-runtime` retains state `002` routing behavior while moving runtime orchestration to Docker Compose.

## Entry Points

- Edge/UI: `http://localhost:18080`
- Angular direct (debug): `http://localhost:18093`
- Service/debug ports preserved (`18082`-`18092`) for troubleshooting.

## Service Discovery Model

- Inter-service traffic uses Docker Compose service DNS names.
- Browser traffic enters only through edge proxy (`edge-proxy` service).
- Edge routing config is sourced from `system/edge-routing.json`.

## Startup Model

- Compose `depends_on` defines startup ordering.
- Runtime script waits for readiness endpoints (`/health`, `/stocks`, `/account/{id}`, `/`) before declaring ready.

## Source-of-Truth Artifacts

- `system/docker-compose.spec.yaml`
- `system/edge-routing.json`
