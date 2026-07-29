# Component List

State: `002-edge-proxy-uncontainerized`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `trader` | Trader Browser | actor | User enters only through edge proxy. |
| `edge` | Edge Proxy | gateway | Single browser-facing origin. |
| `web` | Web Front End Angular | frontend | Served behind edge proxy. |
| `account` | Account Service | service | Account and account-user CRUD. |
| `position` | Position Service | service | Trades and positions query endpoints. |
| `tradeService` | Trade Service | service | Trade submission and validation. |
| `referenceData` | Reference Data | service | Ticker lookup/list. |
| `people` | People Service | service | Directory lookup and validation. |
| `tradeFeed` | Trade Feed | messaging | Socket.IO publish/subscribe bus. |
| `tradeProcessor` | Trade Processor | service | Processes new trades and updates positions. |
| `database` | Database | database | Persistent account, trade, and position state. |
