# System Design

State: `003-containerized-compose-runtime`

## Design Intent

State 003 preserves state 002 routing semantics while moving runtime to Docker Compose and NGINX ingress.

## Runtime Topology / Flow (Spec Extract)

# Runtime Topology (State 003)

State `003-containerized-compose-runtime` retains state `002` routing behavior while moving runtime orchestration to Docker Compose.

## Entry Points

- Ingress/UI: `http://localhost:8080`
- Angular direct (debug): `http://localhost:18093`
- Service/debug ports preserved (`18082`-`18092`) for troubleshooting.

## Service Discovery Model

- Inter-service traffic uses Docker Compose service DNS names.
- Browser traffic enters through NGINX ingress (`ingress` service).
- Ingress routing config is sourced from `system/ingress-nginx.conf.template`.

## Startup Model

- Compose `depends_on` defines startup ordering.
- Runtime script waits for readiness endpoints (`/health`, `/stocks`, `/account/{id}`, `/`) before declaring ready.

## Source-of-Truth Artifacts

- `system/docker-compose.spec.yaml`
- `system/ingress-nginx.conf.template`
