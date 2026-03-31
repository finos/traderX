# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

- State ID: `009-postgres-database-replacement`
- State Title: `PostgreSQL Database Replacement`
- Status: `implemented`
- Suggested Version Tag: `generated/009-postgres-database-replacement/v1`
- Source Branch: `feature/agentic-renovation`
- Source Commit: `68d19a554c7480a615b19c024eb0a88228c6b9ad`
- Generated At (UTC): `2026-03-31T13:14:26Z`

## State Summary

- Builds on state `003` and preserves containerized ingress runtime behavior.
- Replaces H2 runtime database with PostgreSQL container + deterministic init SQL.
- Preserves baseline REST/event contracts and user-visible behavior.

## State Lineage

```mermaid
flowchart LR
  S_CUR["009-postgres-database-replacement (current)"]
  style S_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  S_PREV_003_containerized_compose_runtime["003-containerized-compose-runtime"] --> S_CUR
  click S_PREV_003_containerized_compose_runtime href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-003-containerized-compose-runtime" "Open branch"
  click S_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-009-postgres-database-replacement" "Open current branch"
```

| Direction | State | Branch | Compare |
| --- | --- | --- | --- |
| Previous | `003-containerized-compose-runtime` | [code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/tree/code%2Fgenerated-state-003-containerized-compose-runtime) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-009-postgres-database-replacement) |

State sets:
- Previous states: `003-containerized-compose-runtime`
- Next states: `none`

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-state-009-postgres-database-replacement-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`
PostgreSQL endpoint: `localhost:18083`

Status / stop:

```bash
./scripts/status-state-009-postgres-database-replacement-generated.sh
./scripts/stop-state-009-postgres-database-replacement-generated.sh
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

- Feature pack: `specs/009-postgres-database-replacement`
- Generation entrypoint: `bash pipeline/generate-state.sh 009-postgres-database-replacement`
- Developer learning guide for this snapshot: [LEARNING.md](./LEARNING.md)
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Source commit: https://github.com/finos/traderX/commit/68d19a554c7480a615b19c024eb0a88228c6b9ad
- Feature pack at source commit: https://github.com/finos/traderX/tree/68d19a554c7480a615b19c024eb0a88228c6b9ad/specs/009-postgres-database-replacement
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/68d19a554c7480a615b19c024eb0a88228c6b9ad/docs/spec-kit
