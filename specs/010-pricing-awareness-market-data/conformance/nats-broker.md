# nats-broker Conformance Pack

## User Stories

- backend services can communicate over a shared broker for trades and market prices.
- frontend can receive live account updates and pricing updates over websocket via ingress.

## Functional Requirements

- `FR-1001`
- `FR-1002`
- `FR-1004`
- `FR-1005`
- `FR-1006`
- `FR-1009`
- `FR-1011`
- `FR-1012`
- `FR-1016`

## Non-Functional Requirements

- `NFR-1002`
- `NFR-1003`
- `NFR-1004`
- `NFR-1005`
- `NFR-1006`
- `NFR-1007`

## Acceptance Criteria

- NATS service is reachable and healthy in state runtime.
- Pricing topics (`pricing.<TICKER>`) are observable from websocket clients.
- Publisher cadence/ratio config is exposed and valid via `/health`.
- Trade events include non-null execution price.
- Position events and REST payloads include non-null average cost basis.
- Realtime position updates preserve aggregate blotter semantics (existing security rows update in place).
- UI semantics for market-vs-open and value-vs-cost use deterministic marker/highlight rules.

## Verification References

- `scripts/start-state-010-pricing-awareness-market-data-generated.sh` (planned)
- `scripts/test-state-010-pricing-awareness-market-data.sh` (planned)
