# Component Diagram

State: `003-containerized-compose-runtime`

```mermaid
flowchart LR
  trader["Trader Browser"]
  ingress["NGINX Ingress"]
  web["Web Front End Angular"]
  account["Account Service"]
  position["Position Service"]
  tradeService["Trade Service"]
  referenceData["Reference Data"]
  people["People Service"]
  tradeFeed["Trade Feed"]
  tradeProcessor["Trade Processor"]
  database["Database"]

  trader -->|Single browser entrypoint| ingress
  ingress -->|/| web
  ingress -->|/account-service| account
  ingress -->|/position-service| position
  ingress -->|/trade-service| tradeService
  ingress -->|/reference-data| referenceData
  ingress -->|/people-service| people
  ingress -->|/trade-feed and /socket.io| tradeFeed
  tradeService -->|Validate account| account
  tradeService -->|Validate ticker| referenceData
  tradeService -->|Publish trades/new| tradeFeed
  tradeProcessor -->|Consume and publish updates| tradeFeed
  tradeProcessor -->|Persist trade/position state| database
  account -->|Account persistence| database
  position -->|Query trades/positions| database
  account -->|Validate person for account-user mapping| people
```
