# Functional Testing Guide

State: `001-baseline-uncontainerized-parity`

This guide captures intended functional behavior for this generated snapshot branch.

## What Should Work

- Base case for TraderX generated code.
- Runtime model: uncontainerized local processes in deterministic startup order.
- Browser directly calls multiple service ports (cross-origin CORS behavior is part of this state).

## Suggested Functional Validation

1. Start runtime using [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md).
2. Execute the state's smoke test script when available.
3. Confirm user-facing behavior and invariants described in [LEARNING.md](./LEARNING.md).
4. If behavior differs from expectations, compare with parent state using lineage links in [README.md](./README.md).

## Smoke Test Commands

```bash
ls ./scripts/test-state-*.sh
```

Use the script matching this state id when available.

## Canonical References

- Spec pack: `specs/001-baseline-uncontainerized-parity`
- Runtime guide: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
- Snapshot learning guide: [LEARNING.md](./LEARNING.md)
- Snapshot metadata: [STATE.md](./STATE.md)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Canonical SpecKit docs (source commit): https://github.com/finos/traderX/tree/0b2e1068c66159c48378bd81d55f5a41a7131da1/docs/spec-kit
