# Portfolio Look-Through

Explainable portfolio exposure on the C2 trading runtime.

- Inherits architectural baseline from: `009-order-management-matcher`
- Generated from: `system/architecture.model.json`
- Canonical flows: `system/end-to-end-flows.md`

## Architecture Diagram

```mermaid
flowchart LR
  ui["Exposure UI"]
  api["Exposure service"]
  pg["PostgreSQL source / SQL projection"]
  ui -->|"Same exposure contract"| api
  api -->|"Repeatable-read snapshot"| pg
```

## Node Catalog

| Node | Kind | Label | Notes |
| --- | --- | --- | --- |
| `ui` | service | Exposure UI | - |
| `api` | service | Exposure service | - |
| `pg` | service | PostgreSQL source / SQL projection | - |

