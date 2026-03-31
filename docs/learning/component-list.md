# Component List

State: `007-messaging-nats-replacement`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `trader` | Trader Browser | actor | Uses Angular UI and receives live updates. |
| `ingress` | NGINX Ingress | gateway | Routes REST and websocket traffic. |
| `web` | Web Front End Angular | frontend | Uses nats.ws for account-scoped streams. |
| `nats` | NATS Broker | messaging | Core pub/sub broker for backend and browser streaming. |
| `tradeService` | Trade Service | service | Publishes new trade events. |
| `tradeProcessor` | Trade Processor | service | Consumes and publishes processed/account updates. |
| `account` | Account Service | service | Account and account-user operations. |
| `position` | Position Service | service | Trades/positions query endpoints. |
| `referenceData` | Reference Data | service | Ticker lookup/list. |
| `people` | People Service | service | Identity lookup and validation. |
| `database` | Database | database | Persistent account/trade/position state. |
