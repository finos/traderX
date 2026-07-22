# Functional Testing Guide

State: `010-kubernetes-runtime`

This guide captures intended functional behavior for this generated snapshot branch.

## What Should Work

- Builds on state `009` by moving runtime from Docker Compose to Kubernetes (Kind baseline).
- Uses in-cluster NGINX edge-proxy as browser/API/WebSocket entrypoint at `http://localhost:8080`.
- Preserves C2 functional behavior while changing runtime orchestration and deployment model.

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

- Spec pack: `specs/010-kubernetes-runtime`
- Runtime guide: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
- Snapshot learning guide: [LEARNING.md](./LEARNING.md)
- Snapshot metadata: [STATE.md](./STATE.md)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Canonical SpecKit docs (source commit): https://github.com/finos/traderX/tree/f60def6eff9b988141d59ae6ad864dfd5bc10ce6/docs/spec-kit
