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

## Non-Functional Requirements

- `NFR-1002`
- `NFR-1003`
- `NFR-1004`
- `NFR-1005`

## Acceptance Criteria

- NATS service is reachable and healthy in state runtime.
- Pricing topics (`pricing.<TICKER>`) are observable from websocket clients.
- Trade events include non-null execution price.
- Position events and REST payloads include non-null average cost basis.
- Realtime position updates preserve aggregate blotter semantics (existing security rows update in place).

## Verification References

- `scripts/start-state-010-pricing-awareness-market-data-generated.sh` (planned)
- `scripts/test-state-010-pricing-awareness-market-data.sh` (planned)
