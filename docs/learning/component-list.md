# Component List

State: `009-order-management-matcher`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `developer` | Developer | actor | Local developer using this state. |
| `app_runtime` | TraderX App Runtime | boundary | State 009 pricing/runtime baseline with order-management extensions. |
| `obs_runtime` | Observability Runtime | boundary | LGTM + OTel stack from state 007 carried forward with order telemetry coverage. |
| `ingress` | NGINX Ingress | service | Routes UI, API, and order admin traffic. |
| `trade_ui` | Angular Trade UI | service | Trade ticket, blotters, and admin tab. |
| `order_api` | Order Management API | service | Order create/query/edit/cancel/force-fill endpoints. |
| `order_matcher` | Order Matcher | service | Matches open orders and emits order lifecycle + fill events. |
| `nats` | NATS Broker | service | Realtime transport for pricing, trade, position, and order subjects. |
| `trade_processor` | Trade Processor | service | Consumes fills and persists trades/positions. |
| `prometheus` | Prometheus | service | Scrapes order metrics and blackbox probes. |
| `blackbox` | Blackbox Exporter | service | Probes order endpoints and inherited runtime endpoints. |
| `loki` | Loki | service | Aggregates order and runtime logs. |
| `grafana` | Grafana | service | Dashboards for queue depth, open orders, events, and matcher latency. |
