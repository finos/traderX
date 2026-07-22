# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

![linux/mac support](https://badgen.net/badge/linux%2Fmac/supported/green?icon=linux) ![windows support](https://badgen.net/badge/windows/not%20supported/red?icon=windows)

- State ID: `006-messaging-nats-replacement`
- State Title: `Messaging Layer Replacement with NATS`
- Status: `implemented`
- Suggested Version Tag: `generated/006-messaging-nats-replacement/v1`
- Source Branch: `main`
- Source Commit: `b2618b7dec311eb402dc670efa5872a9e700a27c`
- Generated At (UTC): `2026-07-22T15:36:18Z`

## State Summary

- Builds on state `004` and preserves containerized ingress runtime behavior.
- Replaces Socket.IO trade-feed with NATS broker for backend and browser streaming.
- Preserves baseline user-visible behavior while changing messaging transport.

## State Lineage

```mermaid
flowchart LR
  S_CUR["006-messaging-nats-replacement (current)"]
  style S_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  S_PREV_005_postgres_database_replacement["005-postgres-database-replacement"] --> S_CUR
  click S_PREV_005_postgres_database_replacement href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-005-postgres-database-replacement" "Open branch"
  S_CUR --> S_NEXT_007_observability_lgtm_compose["007-observability-lgtm-compose"]
  click S_NEXT_007_observability_lgtm_compose href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-007-observability-lgtm-compose" "Open branch"
  click S_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-006-messaging-nats-replacement" "Open current branch"
```

| Direction | State | Branch | Compare |
| --- | --- | --- | --- |
| Previous | `005-postgres-database-replacement` | [code/generated-state-005-postgres-database-replacement](https://github.com/finos/traderX/tree/code%2Fgenerated-state-005-postgres-database-replacement) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-005-postgres-database-replacement...code%2Fgenerated-state-006-messaging-nats-replacement) |
| Next | `007-observability-lgtm-compose` | [code/generated-state-007-observability-lgtm-compose](https://github.com/finos/traderX/tree/code%2Fgenerated-state-007-observability-lgtm-compose) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-006-messaging-nats-replacement...code%2Fgenerated-state-007-observability-lgtm-compose) |

State sets:
- Previous states: `005-postgres-database-replacement`
- Next states: `007-observability-lgtm-compose`

## Convergence Status

- Convergence state: `false`
- Convergence level: `none`
- Lineage role: `canonical`
- Dotted-line parents: `none`
- Previous convergence milestone: [004-containerized-compose-runtime](https://github.com/finos/traderX/tree/code%2Fgenerated-state-004-containerized-compose-runtime) (🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-004-containerized-compose-runtime...code%2Fgenerated-state-006-messaging-nats-replacement))
- Next convergence milestone: [007-observability-lgtm-compose](https://github.com/finos/traderX/tree/code%2Fgenerated-state-007-observability-lgtm-compose) (🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-006-messaging-nats-replacement...code%2Fgenerated-state-007-observability-lgtm-compose))

### Convergence Neighborhood

```mermaid
flowchart LR
  C_CUR["006-messaging-nats-replacement (current)"]
  style C_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  C_PREV_004_containerized_compose_runtime["004-containerized-compose-runtime"] --> C_CUR
  click C_PREV_004_containerized_compose_runtime href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-004-containerized-compose-runtime" "Open branch"
  %% compare: https://github.com/finos/traderX/compare/code%2Fgenerated-state-004-containerized-compose-runtime...code%2Fgenerated-state-006-messaging-nats-replacement
  C_CUR --> C_NEXT_007_observability_lgtm_compose["007-observability-lgtm-compose"]
  click C_NEXT_007_observability_lgtm_compose href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-007-observability-lgtm-compose" "Open branch"
  %% compare: https://github.com/finos/traderX/compare/code%2Fgenerated-state-006-messaging-nats-replacement...code%2Fgenerated-state-007-observability-lgtm-compose
  click C_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-006-messaging-nats-replacement" "Open current branch"
```

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-state-006-messaging-nats-replacement-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`
NATS monitor endpoint: `http://localhost:8222/varz`

Status / stop:

```bash
./scripts/status-state-006-messaging-nats-replacement-generated.sh
./scripts/stop-state-006-messaging-nats-replacement-generated.sh
```

## API Explorer

- API explorer (ingress): `http://localhost:8080/api/docs`

## Interactive URLs

- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Trade service Swagger: `http://localhost:18092/v3/api-docs`
- Account service API sample: `http://localhost:18088/account/22214`
- Position service health: `http://localhost:18090/health/alive`



Detailed clone-first instructions: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
Functional validation guide: [FUNCTIONAL_TESTING.md](./FUNCTIONAL_TESTING.md)

## Learning Docs In This Snapshot

- [Docs Index](./docs/README.md)
- [Learning Index](./docs/learning/README.md)
- [Component List](./docs/learning/component-list.md)
- [System Design](./docs/learning/system-design.md)
- [Software Architecture](./docs/learning/software-architecture.md)
- [Component Diagram](./docs/learning/component-diagram.md)

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: `specs/006-messaging-nats-replacement`
- Generation entrypoint: `bash pipeline/generate-state.sh 006-messaging-nats-replacement`
- Developer learning guide for this snapshot: [LEARNING.md](./LEARNING.md)
- Functional validation guide: [FUNCTIONAL_TESTING.md](./FUNCTIONAL_TESTING.md)
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Source commit: https://github.com/finos/traderX/commit/b2618b7dec311eb402dc670efa5872a9e700a27c
- Feature pack at source commit: https://github.com/finos/traderX/tree/b2618b7dec311eb402dc670efa5872a9e700a27c/specs/006-messaging-nats-replacement
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/b2618b7dec311eb402dc670efa5872a9e700a27c/docs/spec-kit
