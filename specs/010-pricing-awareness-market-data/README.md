# Feature Pack 010: Pricing Awareness and Market Data Streaming

Status: Implemented  
Track: `functional`  
Previous state: `007-messaging-nats-replacement`

## Motivation

State `007` introduced robust NATS messaging and browser streaming parity, but trade and position data are still quantity-only.  
This pack adds execution pricing, position average cost basis, and streaming valuation/P&L so the trade workflow reflects realistic price-aware behavior.

## Scope In This State

- Keep runtime model on Docker Compose + NGINX ingress from `007`.
- Add `price-publisher` component:
  - emits `pricing.<TICKER>` messages on NATS using randomized batch cadence (`750-1500ms` default, `25%` symbols per cycle),
  - supports startup bootstrap from snapshot data or yfinance.
- Stamp trade execution price at submission (`trade-service`) and persist it (`trade-processor`).
- Aggregate position average cost basis in persistence model on every trade.
- Align supported symbol universe between `reference-data` and `price-publisher` via shared runtime config.
- Normalize legacy `FB` symbol to `META` in state `010` reference-data responses.
- Expand default sample universe to include financial-services institutions used in demos:
  `MS`, `UBS`, `C`, `GS`, `DB`, `JPM`, `COF`, `DFS`, `FNMA`, `FIS`, `FNF`.
- Extend Angular blotters with:
  - trade execution price and relative execution time,
  - position open/market price/value/P&L with directional and semantic highlighting,
  - total portfolio value and cost basis.

## Artifacts

- `spec.md`
- `requirements/functional-delta.md`
- `requirements/nonfunctional-delta.md`
- `contracts/contract-delta.md`
- `fidelity-profile.md`
- `components/nats-broker.md`
- `components/messaging-migration.md`
- `conformance/nats-broker.md`
- `system/architecture.model.json`
- `system/runtime-topology.md`
- `system/migration-guidance.md`
- `system/messaging-subject-map.md`
- `system/docker-compose.nats.snippet.yaml`
- `system/ingress-nginx.nats-ws.snippet.conf`
- `generation/generation-hook.md`
- `tests/smoke/README.md`
