---
title: API Explorer
---

# API Explorer

TraderX provides a standalone runtime API explorer mounted at `/api/docs`.

The explorer is decoupled from the docs portal codebase and is generated into each runtime output by:

- `pipeline/install-generated-api-explorer.sh`

The explorer UI is static Swagger UI and the service list/spec URLs are metadata-driven from:

- `catalog/state-catalog.json` → `apiCatalog`

## Browse

- Runtime route: `/api/docs`
- Runtime catalog URL: `/api/docs/catalog.json`
- Runtime static contracts: `/api/docs/contracts/*.yaml`

## Usage

Generate and start a state runtime:

```bash
bash pipeline/generate-state.sh <state-id>
./scripts/start-state-<state-id>-generated.sh
```

Then open:

- `http://localhost:18080/api/docs` for edge-proxy states (`002`, `003`)
- `http://localhost:8080/api/docs` for ingress/containerized/Kubernetes states (`004+`)
