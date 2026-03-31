# Component Diagram

State: `009-postgres-database-replacement`

```mermaid
flowchart LR
  trader["Trader Browser"]
  ingress["NGINX Ingress"]
  web["Web Front End Angular"]
  referenceData["Reference Data"]
  tradeFeed["Trade Feed"]
  people["People Service"]
  account["Account Service"]
  position["Position Service"]
  tradeProcessor["Trade Processor"]
  tradeService["Trade Service"]
  database["PostgreSQL Database"]

  trader -->|Single browser entrypoint| ingress
  ingress -->|/| web
  ingress -->|/account-service| account
  ingress -->|/position-service| position
  ingress -->|/trade-service| tradeService
  ingress -->|/reference-data| referenceData
  ingress -->|/people-service| people
  ingress -->|/trade-feed (WS)| tradeFeed
  tradeService -->|Validate account| account
  tradeService -->|Validate ticker| referenceData
  tradeService -->|Publish trade event| tradeFeed
  tradeProcessor -->|Consume/publish account updates| tradeFeed
  account -->|Validate person| people
  account -->|Read/write account data| database
  position -->|Read positions/trades| database
  tradeProcessor -->|Persist processed trades/positions| database
```
