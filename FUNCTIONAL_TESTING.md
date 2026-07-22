# Functional Testing Guide

State: `014-fdc3-intent-interoperability`

This guide captures intended functional behavior for this generated snapshot branch.

## What Should Work

- Builds on state `012` and preserves C3 runtime behavior.
- Adds TraderX app-side FDC3 flows plus a local Sail sidecar and two-tab demo profile.
- Keeps interoperability payloads canonical (`fdc3.instrument.id.ticker`) and tracks Sail-specific workaround logic as technical debt.

## Suggested Functional Validation

1. Start runtime using [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md).
2. Execute the state's smoke test script when available.
3. Confirm user-facing behavior and invariants described in [LEARNING.md](./LEARNING.md).
4. If behavior differs from expectations, compare with parent state using lineage links in [README.md](./README.md).

## Smoke Test Commands

```bash
./scripts/test-state-014-fdc3-intent-interoperability.sh
```

## Canonical References

- Spec pack: `specs/014-fdc3-intent-interoperability`
- Runtime guide: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
- Snapshot learning guide: [LEARNING.md](./LEARNING.md)
- Snapshot metadata: [STATE.md](./STATE.md)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Canonical SpecKit docs (source commit): https://github.com/finos/traderX/tree/f60def6eff9b988141d59ae6ad864dfd5bc10ce6/docs/spec-kit
