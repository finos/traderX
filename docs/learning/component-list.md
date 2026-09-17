# Component List

State: `001-baseline-uncontainerized-parity`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `trader` | Trader Browser | actor | Human user interacting with Angular UI. |
| `web` | Web Front End Angular | frontend | Browser-hosted UI. |
| `account` | Account Service | service | Account and account-user CRUD. |
| `position` | Position Service | service | Trades and positions query endpoints. |
| `tradeService` | Trade Service | service | Trade submission and validation. |
| `referenceData` | Reference Data | service | Ticker lookup/list. |
| `people` | People Service | service | Directory lookup and validation. |
| `tradeFeed` | Trade Feed | messaging | Socket.IO publish/subscribe bus. |
| `tradeProcessor` | Trade Processor | service | Processes new trades and updates positions. |
| `database` | Database | database | Persistent account, trade, and position state. |
