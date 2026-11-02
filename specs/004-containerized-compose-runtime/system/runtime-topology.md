# Runtime Topology (State 004)

State `004-containerized-compose-runtime` retains the predecessor stack’s browser-routing behavior while containerizing the application services and web frontend. Dockerfiles package the components into images; Docker Compose defines how the resulting containers run together, with NGINX ingress, service networking and runtime configuration.

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
