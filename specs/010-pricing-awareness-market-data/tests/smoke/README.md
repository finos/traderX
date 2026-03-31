# Smoke Tests: 010 Pricing Awareness and Market Data

- Primary smoke script: `scripts/test-state-010-pricing-awareness-market-data.sh` (planned)

## Required Checks

1. Runtime startup includes healthy `nats-broker`.
2. Runtime startup includes healthy `price-publisher`.
3. Price lookup endpoint returns quote payload with numeric `price`.
4. Trade submission still accepted on existing REST path and includes stamped `price`.
5. Trade service publish event reaches trade-processor through NATS.
6. Processed trade and position updates are published on account-scoped subjects.
7. Frontend stream subscriber receives account-scoped updates via websocket ingress path.
8. Pricing stream (`pricing.<TICKER>`) is observable via websocket ingress path.
9. Persisted trades include `price`; persisted positions include `averageCostBasis`.
10. Unknown account/ticker validations remain unchanged from prior state.
11. Supported symbol coverage check:
   - every symbol returned by `reference-data /stocks` has quote support from `price-publisher`.
12. Symbol normalization check:
   - `reference-data /stocks/META` returns `200`,
   - `reference-data /stocks/FB` returns `404`.
13. Price publisher health check reports publish cadence configuration (`minMs`, `maxMs`, `ratio`).
14. UI manual/automation check:
   - position blotter market-price marker (`▲/▼/■`) reflects relation to open,
   - market price, position value, and P&L apply expected red/green highlight semantics.
15. Financial-services sample coverage check:
   - `reference-data /stocks` includes `MS`, `UBS`, `C`, `GS`, `DB`, `JPM`, `COF`, `DFS`, `FNMA`, and at least one Fidelity-related symbol (`FIS`/`FNF`),
   - `price-publisher /prices/{ticker}` returns `200` for each of those supported symbols.
