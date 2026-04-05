# Order Management and Matcher

Pricing + observability runtime extended with order management, matcher flow, and order-specific telemetry.

- Generated from: `system/architecture.model.json`
- Canonical flows: `system/end-to-end-flows.md`

## Architecture Diagram

```mermaid
flowchart LR
  developer["Developer"]
  app_runtime["TraderX App Runtime"]
  obs_runtime["Observability Runtime"]
  ingress["NGINX Ingress"]
  trade_ui["Angular Trade UI"]
  order_api["Order Management API"]
  order_matcher["Order Matcher"]
  nats["NATS Broker"]
  trade_processor["Trade Processor"]
  prometheus["Prometheus"]
  blackbox["Blackbox Exporter"]
  loki["Loki"]
  grafana["Grafana"]
  developer -->|"Uses app and admin UI"| ingress
  ingress -->|"Serves UI"| trade_ui
  trade_ui -->|"Calls order APIs"| order_api
  order_api -->|"Submits and updates orders"| order_matcher
  order_api -->|"Publishes lifecycle events"| nats
  order_matcher -->|"Publishes fills and status"| nats
  nats -->|"Delivers matcher-generated fills"| trade_processor
  prometheus -->|"Scrapes /metrics"| order_matcher
  prometheus -->|"Scrapes probe metrics"| blackbox
  blackbox -->|"HTTP probes"| order_api
  blackbox -->|"HTTP probes"| order_matcher
  order_matcher -->|"Structured logs via promtail"| loki
  developer -->|"Views order observability"| grafana
  grafana -->|"Queries metrics"| prometheus
  grafana -->|"Queries logs"| loki
```

## Node Catalog

| Node | Kind | Label | Notes |
| --- | --- | --- | --- |
| `developer` | actor | Developer | Local developer using this state. |
| `app_runtime` | boundary | TraderX App Runtime | State 012 pricing runtime with order-management extensions. |
| `obs_runtime` | boundary | Observability Runtime | LGTM + OTel stack from state 012 with order telemetry coverage. |
| `ingress` | service | NGINX Ingress | Routes UI, API, and order admin traffic. |
| `trade_ui` | service | Angular Trade UI | Trade ticket, blotters, and admin tab. |
| `order_api` | service | Order Management API | Order create/query/edit/cancel/force-fill endpoints. |
| `order_matcher` | service | Order Matcher | Matches open orders and emits order lifecycle + fill events. |
| `nats` | service | NATS Broker | Realtime transport for pricing, trade, position, and order subjects. |
| `trade_processor` | service | Trade Processor | Consumes fills and persists trades/positions. |
| `prometheus` | service | Prometheus | Scrapes order metrics and blackbox probes. |
| `blackbox` | service | Blackbox Exporter | Probes order endpoints and inherited runtime endpoints. |
| `loki` | service | Loki | Aggregates order and runtime logs. |
| `grafana` | service | Grafana | Dashboards for queue depth, open orders, events, and matcher latency. |

