# Functional Testing Guide

State: `008-pricing-awareness-market-data`

This guide captures intended functional behavior for this generated snapshot branch.

## What Should Work

- Builds on state `007` and preserves NATS-based messaging + compose ingress runtime behavior.
- Adds market pricing stream, trade execution price stamping, and position average cost basis aggregation.
- Extends UI blotters with pricing/value/P&L visualization while preserving baseline trade/account workflows.

## Suggested Functional Validation

1. Start runtime using [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md).
2. Execute the state's smoke test script when available.
3. Confirm user-facing behavior and invariants described in [LEARNING.md](./LEARNING.md).
4. If behavior differs from expectations, compare with parent state using lineage links in [README.md](./README.md).

## Smoke Test Commands

```bash
./scripts/test-state-008-pricing-awareness-market-data.sh
```
```bash
./scripts/test-state-008-pricing-awareness-market-data.sh --skip-messaging
./scripts/test-messaging-008-pricing-awareness-market-data.sh
```

## Canonical References

- Spec pack: `specs/008-pricing-awareness-market-data`
- Runtime guide: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
- Snapshot learning guide: [LEARNING.md](./LEARNING.md)
- Snapshot metadata: [STATE.md](./STATE.md)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Canonical SpecKit docs (source commit): https://github.com/finos/traderX/tree/f0056d6753b9a76295ce40ede1f32c30bd2c5f27/docs/spec-kit
