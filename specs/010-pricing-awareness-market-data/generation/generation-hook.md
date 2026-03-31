# Generation Hook: 010 Pricing Awareness and Market Data

- Hook script: `pipeline/generate-state-010-pricing-awareness-market-data.sh`
- Feature pack: `specs/010-pricing-awareness-market-data`

## Intended Hook Flow

1. Generate parent state `007` as base output.
2. Apply state-010 overlay files onto generated target output.
3. Inject pricing component/runtime additions:
   - `price-publisher` component files,
   - compose integration and ingress route updates.
4. Inject service/frontend pricing deltas:
   - trade-service price stamping,
   - trade-processor trade/position schema updates,
   - Angular valuation + totals updates.
5. Emit deterministic target output for state `010`.

## Implementation Notes

- Keep baseline 007 runtime topology intact while adding pricing functionality.
- Preserve readiness for future Kubernetes functional branching from state 010.
