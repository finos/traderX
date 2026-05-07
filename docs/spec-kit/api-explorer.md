---
title: API Explorer
---

# API Explorer

TraderX provides a standalone runtime API explorer mounted at `/api/docs`.

The explorer is decoupled from the docs portal codebase and is generated into each runtime output by:

- `pipeline/install-generated-api-explorer.sh`

The explorer UI is static Swagger UI and the service list/spec URLs are metadata-driven from:

- `catalog/state-catalog.json` → `apiCatalog`

For states with message-bus subject maps (`006+`, with required pub/sub inspector baseline from `008+`), the same generated runtime catalog also carries inspector topic metadata derived from:

- `specs/<state-id>/system/messaging-subject-map.md` → `/api/docs/catalog.json` → `messagingSubjects`

## Browse

- Runtime route: `/api/docs`
- Runtime catalog URL: `/api/docs/catalog.json`
- Runtime static contracts: `/api/docs/contracts/*.yaml`
- Runtime pub/sub inspector (canonical): `/api/docs/pubsub-inspector.html` (`/api/docs/pubsub-inspector` remains supported for compatibility)

## Usage

Generate and start a state runtime:

```bash
bash pipeline/generate-state.sh <state-id>
```

For process-based states (`001`, `002`, `003`):

```bash
./scripts/start-base-uncontainerized-generated.sh --build-only
./scripts/start-base-uncontainerized-generated.sh
# or for state 002/003:
# ./scripts/start-state-002-edge-proxy-generated.sh --build-only
# ./scripts/start-state-002-edge-proxy-generated.sh
```

For containerized/Kubernetes states (`004+`):

```bash
./scripts/start-state-<state-id>-generated.sh
# optional restart without rebuild
./scripts/start-state-<state-id>-generated.sh --skip-build
```

Then open:

- `http://localhost:18080/api/docs` for edge-proxy states (`002`, `003`)
- `http://localhost:8080/api/docs` for ingress/containerized/Kubernetes states (`004+`)
