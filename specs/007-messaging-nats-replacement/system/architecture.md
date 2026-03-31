# Architecture (State 007 Messaging NATS Replacement)

State 007 replaces Socket.IO trade-feed messaging with NATS while preserving state 003 containerized runtime and ingress entry model.

- Inherits architectural baseline from: `003-containerized-compose-runtime`
- Generated from: `system/architecture.model.json`
- Canonical flows: `../001-baseline-uncontainerized-parity/system/end-to-end-flows.md`

## Entry Points

- `ingress`: `http://localhost:8080`
- `nats-ws`: `ws://localhost:8080/nats-ws`

## Architecture Diagram

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
  trader -->|"Single browser entrypoint"| ingress
  ingress -->|"/"| web
  ingress -->|"/account-service"| account
  ingress -->|"/position-service"| position
  ingress -->|"/trade-service"| tradeService
  ingress -->|"/reference-data"| referenceData
  ingress -->|"/people-service"| people
  ingress -->|"/nats-ws (WS upgrade)"| nats
  tradeService -->|"Validate account"| account
  tradeService -->|"Validate ticker"| referenceData
  tradeService -->|"Publish trades.new"| nats
  tradeProcessor -->|"Consume trades.new, publish account updates"| nats
  web -->|"Subscribe account-scoped streams"| nats
  tradeProcessor -->|"Persist trade/position state"| database
  account -->|"Account persistence"| database
  position -->|"Query trades/positions"| database
  account -->|"Validate person"| people
```

## Node Catalog

| Node | Kind | Label | Notes |
| --- | --- | --- | --- |
| `trader` | actor | Trader Browser | Uses Angular UI and receives live updates. |
| `ingress` | gateway | NGINX Ingress | Routes REST and websocket traffic. |
| `web` | frontend | Web Front End Angular | Uses nats.ws for account-scoped streams. |
| `nats` | messaging | NATS Broker | Core pub/sub broker for backend and browser streaming. |
| `tradeService` | service | Trade Service | Publishes new trade events. |
| `tradeProcessor` | service | Trade Processor | Consumes and publishes processed/account updates. |
| `account` | service | Account Service | Account and account-user operations. |
| `position` | service | Position Service | Trades/positions query endpoints. |
| `referenceData` | service | Reference Data | Ticker lookup/list. |
| `people` | service | People Service | Identity lookup and validation. |
| `database` | database | Database | Persistent account/trade/position state. |

## State Notes

- State 007 is an architecture-track branch from state 003.
- Messaging transport changes to NATS; business behavior remains baseline-compatible.
- JetStream durability is intentionally deferred to a future state.

