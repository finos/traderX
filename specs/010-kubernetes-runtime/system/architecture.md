# Architecture (State 010 Kubernetes Runtime)

State 010 preserves state 009 browser/API routing behavior while running all services on a local Kubernetes cluster.

- Inherits architectural baseline from: `009-order-management-matcher`
- Generated from: `system/architecture.model.json`
- Canonical flows: `../001-baseline-uncontainerized-parity/system/end-to-end-flows.md`

## Entry Points

- `edge-proxy`: `http://localhost:8080`
- `edge-health`: `http://localhost:8080/health`
- `grafana`: `http://localhost:8080/grafana`
- `prometheus`: `http://localhost:8080/prometheus`

## Architecture Diagram

```mermaid
flowchart LR
  developer["Developer"]
  cluster["Kind Kubernetes Cluster"]
  edge["NGINX Edge Proxy"]
  web["Web Front End Angular"]
  account["Account Service"]
  position["Position Service"]
  tradeService["Trade Service"]
  referenceData["Reference Data"]
  people["People Service"]
  nats["NATS Broker"]
  tradeProcessor["Trade Processor"]
  database["Database"]
  grafana["Grafana"]
  prometheus["Prometheus"]
  developer -->|"Starts runtime"| cluster
  developer -->|"Browser access :8080"| edge
  edge -->|"/"| web
  edge -->|"/account-service"| account
  edge -->|"/position-service"| position
  edge -->|"/trade-service"| tradeService
  edge -->|"/reference-data"| referenceData
  edge -->|"/people-service"| people
  edge -->|"/nats-ws"| nats
  edge -->|"/trade-processor"| tradeProcessor
  edge -->|"/grafana"| grafana
  edge -->|"/prometheus"| prometheus
  tradeService -->|"Validate account"| account
  tradeService -->|"Validate ticker"| referenceData
  tradeService -->|"Publish trades/new"| nats
  tradeProcessor -->|"Consume and publish updates"| nats
  tradeProcessor -->|"Persist trade/position state"| database
  account -->|"Account persistence"| database
  position -->|"Query trades/positions"| database
  account -->|"Validate person for account-user mapping"| people
```

## Node Catalog

| Node | Kind | Label | Notes |
| --- | --- | --- | --- |
| `developer` | actor | Developer | Runs local Kind-based Kubernetes runtime. |
| `cluster` | boundary | Kind Kubernetes Cluster | Local cluster namespace and workloads. |
| `edge` | gateway | NGINX Edge Proxy | Single browser entrypoint for UI/API/WebSocket routes. |
| `web` | frontend | Web Front End Angular | Angular frontend served behind edge proxy. |
| `account` | service | Account Service | Account and account-user APIs. |
| `position` | service | Position Service | Positions and trades query API. |
| `tradeService` | service | Trade Service | Trade order submission and validation. |
| `referenceData` | service | Reference Data | Ticker metadata lookup. |
| `people` | service | People Service | Person lookup and matching APIs. |
| `nats` | messaging | NATS Broker | Messaging backbone for trade, position, pricing, and order lifecycle streams. |
| `tradeProcessor` | service | Trade Processor | Consumes trade events and persists settled state. |
| `database` | database | Database | PostgreSQL persistence service. |
| `grafana` | observability | Grafana | Dashboard and observability visualization UI. |
| `prometheus` | observability | Prometheus | Metrics collection and query engine. |

## State Notes

- Functional behavior remains intentionally equivalent to state 009.
- Primary delta is runtime/operations model (Compose to Kubernetes).
- Edge proxy remains NGINX-based to keep route semantics stable.
- Observability stack from state 009 remains available in Kubernetes runtime.

