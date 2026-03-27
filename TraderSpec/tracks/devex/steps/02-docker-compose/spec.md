# Spec: DevEx 02 Docker Compose

- `stepId`: `devex-02-docker-compose`
- `inheritsFrom`: `devex-01-foundation`
- `requirementMode`: `nfr-overlay-only`

## NFR Additions

- Containerized local execution with Docker Compose.
- Stable service discovery and startup ordering.
- Health-gated startup and teardown.

## Acceptance

- Compose up/down runs reproducibly.
- Service endpoints become healthy under compose runtime.
