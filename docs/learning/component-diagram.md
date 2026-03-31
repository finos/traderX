# Component Diagram

State: `007-messaging-nats-replacement`

```mermaid
flowchart LR
  trader["Trader Browser"]
  ingress["NGINX Ingress"]
  web["Web Front End Angular"]
  nats["NATS Broker"]
  tradeService["Trade Service"]
  tradeProcessor["Trade Processor"]
  account["Account Service"]
  position["Position Service"]
  referenceData["Reference Data"]
  people["People Service"]
  database["Database"]

  trader -->|Single browser entrypoint| ingress
  ingress -->|/| web
  ingress -->|/account-service| account
  ingress -->|/position-service| position
  ingress -->|/trade-service| tradeService
  ingress -->|/reference-data| referenceData
  ingress -->|/people-service| people
  ingress -->|/nats-ws (WS upgrade)| nats
  tradeService -->|Validate account| account
  tradeService -->|Validate ticker| referenceData
  tradeService -->|Publish trades.new| nats
  tradeProcessor -->|Consume trades.new, publish account updates| nats
  web -->|Subscribe account-scoped streams| nats
  tradeProcessor -->|Persist trade/position state| database
  account -->|Account persistence| database
  position -->|Query trades/positions| database
  account -->|Validate person| people
```
