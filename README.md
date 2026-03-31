# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

- State ID: `007-messaging-nats-replacement`
- State Title: `Messaging Layer Replacement with NATS`
- Status: `implemented`
- Suggested Version Tag: `generated/007-messaging-nats-replacement/v1`
- Source Branch: `feature/agentic-renovation`
- Source Commit: `68d19a554c7480a615b19c024eb0a88228c6b9ad`
- Generated At (UTC): `2026-03-31T13:12:23Z`

## State Summary

- Builds on state `003` and preserves containerized ingress runtime behavior.
- Replaces Socket.IO trade-feed with NATS broker for backend and browser streaming.
- Preserves baseline user-visible behavior while changing messaging transport.

## State Lineage

```mermaid
flowchart LR
  S_CUR["007-messaging-nats-replacement (current)"]
  style S_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  S_PREV_003_containerized_compose_runtime["003-containerized-compose-runtime"] --> S_CUR
  click S_PREV_003_containerized_compose_runtime href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-003-containerized-compose-runtime" "Open branch"
  S_CUR --> S_NEXT_010_pricing_awareness_market_data["010-pricing-awareness-market-data"]
  click S_NEXT_010_pricing_awareness_market_data href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-010-pricing-awareness-market-data" "Open branch"
  click S_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-007-messaging-nats-replacement" "Open current branch"
```

| Direction | State | Branch | Compare |
| --- | --- | --- | --- |
| Previous | `003-containerized-compose-runtime` | [code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/tree/code%2Fgenerated-state-003-containerized-compose-runtime) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-007-messaging-nats-replacement) |
| Next | `010-pricing-awareness-market-data` | [code/generated-state-010-pricing-awareness-market-data](https://github.com/finos/traderX/tree/code%2Fgenerated-state-010-pricing-awareness-market-data) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-messaging-nats-replacement...code%2Fgenerated-state-010-pricing-awareness-market-data) |

State sets:
- Previous states: `003-containerized-compose-runtime`
- Next states: `010-pricing-awareness-market-data`

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-state-007-messaging-nats-replacement-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`
NATS monitor endpoint: `http://localhost:8222/varz`

Status / stop:

```bash
./scripts/status-state-007-messaging-nats-replacement-generated.sh
./scripts/stop-state-007-messaging-nats-replacement-generated.sh
```

Detailed clone-first instructions: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)

## Learning Docs In This Snapshot

- [Docs Index](./docs/README.md)
- [Learning Index](./docs/learning/README.md)
- [Component List](./docs/learning/component-list.md)
- [System Design](./docs/learning/system-design.md)
- [Software Architecture](./docs/learning/software-architecture.md)
- [Component Diagram](./docs/learning/component-diagram.md)

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: `specs/007-messaging-nats-replacement`
- Generation entrypoint: `bash pipeline/generate-state.sh 007-messaging-nats-replacement`
- Developer learning guide for this snapshot: [LEARNING.md](./LEARNING.md)
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Source commit: https://github.com/finos/traderX/commit/68d19a554c7480a615b19c024eb0a88228c6b9ad
- Feature pack at source commit: https://github.com/finos/traderX/tree/68d19a554c7480a615b19c024eb0a88228c6b9ad/specs/007-messaging-nats-replacement
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/68d19a554c7480a615b19c024eb0a88228c6b9ad/docs/spec-kit
