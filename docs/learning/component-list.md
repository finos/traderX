# Component List

State: `010-kubernetes-runtime`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `developer` | Developer | actor | Runs local Kind-based Kubernetes runtime. |
| `cluster` | Kind Kubernetes Cluster | boundary | Local cluster namespace and workloads. |
| `edge` | NGINX Edge Proxy | gateway | Single browser entrypoint for UI/API/WebSocket routes. |
| `web` | Web Front End Angular | frontend | Angular frontend served behind edge proxy. |
| `account` | Account Service | service | Account and account-user APIs. |
| `position` | Position Service | service | Positions and trades query API. |
| `tradeService` | Trade Service | service | Trade order submission and validation. |
| `referenceData` | Reference Data | service | Ticker metadata lookup. |
| `people` | People Service | service | Person lookup and matching APIs. |
| `nats` | NATS Broker | messaging | Messaging backbone for trade, position, pricing, and order lifecycle streams. |
| `tradeProcessor` | Trade Processor | service | Consumes trade events and persists settled state. |
| `database` | Database | database | PostgreSQL persistence service. |
| `grafana` | Grafana | observability | Dashboard and observability visualization UI. |
| `prometheus` | Prometheus | observability | Metrics collection and query engine. |
