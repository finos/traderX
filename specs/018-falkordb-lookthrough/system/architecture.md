# FalkorDB Portfolio Look-Through

Explainable portfolio exposure on the C2 trading runtime.

- Inherits architectural baseline from: `017-portfolio-lookthrough`
- Generated from: `system/architecture.model.json`
- Canonical flows: `system/end-to-end-flows.md`

## Architecture Diagram

```mermaid
flowchart LR
  ui["Exposure UI"]
  api["Exposure service"]
  pg["PostgreSQL source / SQL projection"]
  graph["FalkorDB projection"]
  ui -->|"Same exposure contract"| api
  api -->|"Repeatable-read snapshot"| pg
  api -->|"Versioned load / Cypher traversal"| graph
```

## Node Catalog

| Node | Kind | Label | Notes |
| --- | --- | --- | --- |
| `ui` | service | Exposure UI | - |
| `api` | service | Exposure service | - |
| `pg` | service | PostgreSQL source / SQL projection | - |
| `graph` | service | FalkorDB projection | - |

