# Component List

State: `010-pricing-awareness-market-data`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `trader` | Trader Browser | actor | Uses Angular UI and receives realtime trade, position, and pricing updates. |
| `ingress` | NGINX Ingress | gateway | Routes REST and websocket traffic. |
| `web` | Web Front End Angular | frontend | Subscribes to account and pricing streams via nats.ws. |
| `nats` | NATS Broker | messaging | Pub/sub broker for backend and browser streaming. |
| `pricePublisher` | Price Publisher | service | Publishes `pricing.<TICKER>` and exposes REST quote endpoint. |
| `tradeService` | Trade Service | service | Validates account/ticker and stamps execution price before publishing orders. |
| `tradeProcessor` | Trade Processor | service | Processes trades, persists price/cost basis, emits account updates. |
| `account` | Account Service | service | Account and account-user operations. |
| `position` | Position Service | service | Trades/positions query endpoints. |
| `referenceData` | Reference Data | service | Ticker lookup/list. |
| `people` | People Service | service | Identity lookup and validation. |
| `database` | Database | database | Persistent account/trade/position state. |
