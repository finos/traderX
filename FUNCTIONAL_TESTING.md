# Functional Testing Guide

State: `007-observability-lgtm-compose`

This guide captures intended functional behavior for this generated snapshot branch.

## What Should Work

- Generated code snapshot for TraderX state transition.

## Suggested Functional Validation

1. Start runtime using [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md).
2. Execute the state's smoke test script when available.
3. Confirm user-facing behavior and invariants described in [LEARNING.md](./LEARNING.md).
4. If behavior differs from expectations, compare with parent state using lineage links in [README.md](./README.md).

## Smoke Test Commands

```bash
./scripts/test-state-007-observability-lgtm-compose.sh
```

## Canonical References

- Spec pack: `specs/007-observability-lgtm-compose`
- Runtime guide: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
- Snapshot learning guide: [LEARNING.md](./LEARNING.md)
- Snapshot metadata: [STATE.md](./STATE.md)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Canonical SpecKit docs (source commit): https://github.com/finos/traderX/tree/b2618b7dec311eb402dc670efa5872a9e700a27c/docs/spec-kit
