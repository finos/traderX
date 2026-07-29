# Component List

State: `014-fdc3-intent-interoperability`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `trader` | Trader | actor | User interacting with TraderX blotters and tickets. |
| `traderxUi` | TraderX Angular UI | service | Trade/order/position views plus FDC3 integration adapter. |
| `traderxIngress` | TraderX Ingress | gateway | NGINX ingress for TraderX UI/API traffic. |
| `sailSidecar` | Sail Sidecar | service | Local Sail desktop-agent runtime hosted outside TraderX ingress. |
| `sailDirectory` | Sail App Directory Profile | component | Seeded app-directory records for TraderX and demo apps. |
| `demoApps` | Demo FDC3 Apps | service | Chart/quote/workbench apps participating in ticker workflows. |
| `orderApi` | Order Matcher API | service | Order listing and lifecycle endpoints used by order flows. |
| `tradeApi` | Trade Service API | service | Trade creation/query endpoints used by trade ticket flows. |
| `positionApi` | Position Service API | service | Position/blotter data source for symbol-selected rows. |
| `nats` | NATS Broker | service | Realtime ticker and lifecycle updates via websocket gateway. |
