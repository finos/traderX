# Component Spec: container-runtime-packaging

## Role

Define container build/run packaging for the full TraderX baseline component set in state `003`.

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
- `edge-proxy`

## Requirements

- Every component must have a generated `Dockerfile.compose`.
- Compose wiring must come from `system/docker-compose.spec.yaml`.
- Edge routes must be sourced from `system/edge-routing.json`.
- Runtime must preserve baseline flow compatibility through edge entrypoint.

## Generation Surface

- `pipeline/generate-state-003-compose-assets.sh`
- `scripts/start-state-003-containerized-generated.sh`
- `scripts/stop-state-003-containerized-generated.sh`
- `scripts/status-state-003-containerized-generated.sh`
- `scripts/test-state-003-containerized.sh`
