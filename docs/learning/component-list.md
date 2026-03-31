# Component List

State: `009-postgres-database-replacement`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `trader` | Trader Browser | actor | Uses Angular UI via ingress. |
| `ingress` | NGINX Ingress | gateway | Single browser entrypoint for UI + API + websocket. |
| `web` | Web Front End Angular | frontend | TraderX UI. |
| `referenceData` | Reference Data | service | Ticker lookup/list. |
| `tradeFeed` | Trade Feed | messaging | Socket.IO pub/sub layer (unchanged from state 003). |
| `people` | People Service | service | Identity lookup and validation. |
| `account` | Account Service | service | Account and account-user operations using PostgreSQL. |
| `position` | Position Service | service | Trades/positions query operations using PostgreSQL. |
| `tradeProcessor` | Trade Processor | service | Trade processing and persistence using PostgreSQL. |
| `tradeService` | Trade Service | service | Trade submission and validation. |
| `database` | PostgreSQL Database | database | Persistent account/trade/position state. |
