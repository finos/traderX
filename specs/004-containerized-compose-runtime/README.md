# Feature Pack 004: Containerized Compose Runtime

Status: Implemented (pending release validation/tag)

This pack defines the next state after `003-agentic-harness-foundation`.

Primary intent:

- move from process-based local runtime to Docker/Docker Compose orchestration,
- use NGINX as the containerized ingress layer for browser/API/WebSocket entry,
- preserve approved functional behavior,
- document runtime NFR changes explicitly in spec artifacts.

Implemented architecture artifacts:

- `system/architecture.model.json` + generated `system/architecture.md`
- `system/runtime-topology.md`
- `system/docker-compose.spec.yaml`
