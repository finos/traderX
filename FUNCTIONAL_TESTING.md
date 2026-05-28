# Functional Testing Guide

State: `006-messaging-nats-replacement`

This guide captures intended functional behavior for this generated snapshot branch.

## What Should Work

- Builds on state `004` and preserves containerized ingress runtime behavior.
- Replaces Socket.IO trade-feed with NATS broker for backend and browser streaming.
- Preserves baseline user-visible behavior while changing messaging transport.

## Suggested Functional Validation

1. Start runtime using [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md).
2. Execute the state's smoke test script when available.
3. Confirm user-facing behavior and invariants described in [LEARNING.md](./LEARNING.md).
4. If behavior differs from expectations, compare with parent state using lineage links in [README.md](./README.md).

## Smoke Test Commands

```bash
./scripts/test-state-006-messaging-nats-replacement.sh
```

## Canonical References

- Spec pack: `specs/006-messaging-nats-replacement`
- Runtime guide: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
- Snapshot learning guide: [LEARNING.md](./LEARNING.md)
- Snapshot metadata: [STATE.md](./STATE.md)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Canonical SpecKit docs (source commit): https://github.com/finos/traderX/tree/0313dc7bf828e4933b788834802bda10b8200bf5/docs/spec-kit
