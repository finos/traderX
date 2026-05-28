# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

![linux/mac support](https://badgen.net/badge/linux%2Fmac/supported/green?icon=linux) ![windows support](https://badgen.net/badge/windows/supported/green?icon=windows)

- State ID: `003-agentic-harness-foundation`
- State Title: `Agentic Harness Foundation`
- Status: `implemented`
- Suggested Version Tag: `generated/003-agentic-harness-foundation/v1`
- Source Branch: `codex/address-actions-cves-20260528`
- Source Commit: `0313dc7bf828e4933b788834802bda10b8200bf5`
- Generated At (UTC): `2026-05-28T05:16:35Z`

## State Summary

- Builds on state `002` while preserving uncontainerized edge-proxy runtime behavior.
- Adds generated repository harness metadata (`AGENTS.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`).
- Clarifies contribution flow: durable enhancements belong in upstream specs/state packs.

## State Lineage

```mermaid
flowchart LR
  S_CUR["003-agentic-harness-foundation (current)"]
  style S_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  S_PREV_002_edge_proxy_uncontainerized["002-edge-proxy-uncontainerized"] --> S_CUR
  click S_PREV_002_edge_proxy_uncontainerized href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-002-edge-proxy-uncontainerized" "Open branch"
  S_CUR --> S_NEXT_004_containerized_compose_runtime["004-containerized-compose-runtime"]
  click S_NEXT_004_containerized_compose_runtime href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-004-containerized-compose-runtime" "Open branch"
  click S_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-003-agentic-harness-foundation" "Open current branch"
```

| Direction | State | Branch | Compare |
| --- | --- | --- | --- |
| Previous | `002-edge-proxy-uncontainerized` | [code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/tree/code%2Fgenerated-state-002-edge-proxy-uncontainerized) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-002-edge-proxy-uncontainerized...code%2Fgenerated-state-003-agentic-harness-foundation) |
| Next | `004-containerized-compose-runtime` | [code/generated-state-004-containerized-compose-runtime](https://github.com/finos/traderX/tree/code%2Fgenerated-state-004-containerized-compose-runtime) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-agentic-harness-foundation...code%2Fgenerated-state-004-containerized-compose-runtime) |

State sets:
- Previous states: `002-edge-proxy-uncontainerized`
- Next states: `004-containerized-compose-runtime`

## Convergence Status

- Convergence state: `false`
- Convergence level: `none`
- Lineage role: `prelude`
- Dotted-line parents: `none`
- Previous convergence milestone: `none`
- Next convergence milestone: [004-containerized-compose-runtime](https://github.com/finos/traderX/tree/code%2Fgenerated-state-004-containerized-compose-runtime) (🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-agentic-harness-foundation...code%2Fgenerated-state-004-containerized-compose-runtime))

### Convergence Neighborhood

```mermaid
flowchart LR
  C_CUR["003-agentic-harness-foundation (current)"]
  style C_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  C_CUR --> C_NEXT_004_containerized_compose_runtime["004-containerized-compose-runtime"]
  click C_NEXT_004_containerized_compose_runtime href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-004-containerized-compose-runtime" "Open branch"
  %% compare: https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-agentic-harness-foundation...code%2Fgenerated-state-004-containerized-compose-runtime
  click C_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-003-agentic-harness-foundation" "Open current branch"
```

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-state-003-agentic-harness-foundation-generated.sh
```

```powershell
./scripts/start-state-003-agentic-harness-foundation-generated.ps1
```

Browser endpoint (via edge proxy): `http://localhost:18080`

State-specific generated metadata:

- `AGENTS.md`
- `ARCHITECTURE.md`
- `CONTRIBUTING.md`

Status / stop:

```bash
./scripts/status-state-003-agentic-harness-foundation-generated.sh
./scripts/stop-state-003-agentic-harness-foundation-generated.sh
```

```powershell
./scripts/status-state-003-agentic-harness-foundation-generated.ps1
./scripts/stop-state-003-agentic-harness-foundation-generated.ps1
```

## API Explorer

- API explorer (edge): `http://localhost:18080/api/docs`

## Interactive URLs

- UI (edge): `http://localhost:18080`
- API explorer (edge): `http://localhost:18080/api/docs`
- Trade service Swagger (edge): `http://localhost:18080/trade-service/v3/api-docs`
- Account service Swagger (edge): `http://localhost:18080/account-service/v3/api-docs`

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

- Feature pack: `specs/003-agentic-harness-foundation`
- Generation entrypoint: `bash pipeline/generate-state.sh 003-agentic-harness-foundation`
- Developer learning guide for this snapshot: [LEARNING.md](./LEARNING.md)
- Functional validation guide: [FUNCTIONAL_TESTING.md](./FUNCTIONAL_TESTING.md)
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Source commit: https://github.com/finos/traderX/commit/0313dc7bf828e4933b788834802bda10b8200bf5
- Feature pack at source commit: https://github.com/finos/traderX/tree/0313dc7bf828e4933b788834802bda10b8200bf5/specs/003-agentic-harness-foundation
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/0313dc7bf828e4933b788834802bda10b8200bf5/docs/spec-kit
