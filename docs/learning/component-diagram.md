# Component Diagram

State: `002-edge-proxy-uncontainerized`

```mermaid
flowchart LR
  trader["Trader Browser"]
  edge["Edge Proxy"]
  web["Web Front End Angular"]
  account["Account Service"]
  position["Position Service"]
  tradeService["Trade Service"]
  referenceData["Reference Data"]
  people["People Service"]
  tradeFeed["Trade Feed"]
  tradeProcessor["Trade Processor"]
  database["Database"]

  trader -->|Single browser entrypoint| edge
  edge -->|/| web
  edge -->|/account-service| account
  edge -->|/position-service| position
  edge -->|/trade-service| tradeService
  edge -->|/reference-data| referenceData
  edge -->|/people-service| people
  edge -->|/socket.io| tradeFeed
  tradeService -->|Validate account| account
  tradeService -->|Validate ticker| referenceData
  tradeService -->|Publish trades/new| tradeFeed
  tradeProcessor -->|Consume and publish updates| tradeFeed
  tradeProcessor -->|Persist trade/position state| database
  account -->|Validate person for account-user mapping| people
  account -->|Account persistence| database
  position -->|Query trades/positions| database
```
