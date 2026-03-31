# Component Diagram

State: `010-pricing-awareness-market-data`

```mermaid
flowchart LR
  trader["Trader Browser"]
  ingress["NGINX Ingress"]
  web["Web Front End Angular"]
  nats["NATS Broker"]
  pricePublisher["Price Publisher"]
  tradeService["Trade Service"]
  tradeProcessor["Trade Processor"]
  account["Account Service"]
  position["Position Service"]
  referenceData["Reference Data"]
  people["People Service"]
  database["Database"]

  trader -->|Single browser entrypoint| ingress
  ingress -->|/| web
  ingress -->|/price-publisher| pricePublisher
  ingress -->|/nats-ws (WS upgrade)| nats
  tradeService -->|Validate ticker| referenceData
  tradeService -->|Validate account| account
  tradeService -->|Fetch execution price| pricePublisher
  tradeService -->|Publish /trades| nats
  tradeProcessor -->|Consume /trades, publish account updates| nats
  pricePublisher -->|Publish pricing.<TICKER>| nats
  web -->|Subscribe account + pricing topics| nats
  tradeProcessor -->|Persist trades + positions| database
  position -->|Query trades + positions| database
  account -->|Validate person| people
```
