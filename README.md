# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

![linux/mac support](https://badgen.net/badge/linux%2Fmac/supported/green?icon=linux) ![windows support](https://badgen.net/badge/windows/supported/green?icon=windows)

- State ID: `002-edge-proxy-uncontainerized`
- State Title: `Edge Proxy Uncontainerized`
- Status: `implemented`
- Suggested Version Tag: `generated/002-edge-proxy-uncontainerized/v1`
- Source Branch: `codex/address-actions-cves-20260528`
- Source Commit: `0313dc7bf828e4933b788834802bda10b8200bf5`
- Generated At (UTC): `2026-05-28T05:15:00Z`

## State Summary

- Builds on state `001` while keeping uncontainerized process runtime.
- Adds `edge-proxy` as a single browser-facing origin for UI + API + WebSocket traffic.
- Preserves baseline functional behavior with topology-focused NFR deltas.

## State Lineage

```mermaid
flowchart LR
  S_CUR["002-edge-proxy-uncontainerized (current)"]
  style S_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  S_PREV_001_baseline_uncontainerized_parity["001-baseline-uncontainerized-parity"] --> S_CUR
  click S_PREV_001_baseline_uncontainerized_parity href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-001-baseline-uncontainerized-parity" "Open branch"
  S_CUR --> S_NEXT_003_agentic_harness_foundation["003-agentic-harness-foundation"]
  click S_NEXT_003_agentic_harness_foundation href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-003-agentic-harness-foundation" "Open branch"
  click S_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-002-edge-proxy-uncontainerized" "Open current branch"
```

| Direction | State | Branch | Compare |
| --- | --- | --- | --- |
| Previous | `001-baseline-uncontainerized-parity` | [code/generated-state-001-baseline-uncontainerized-parity](https://github.com/finos/traderX/tree/code%2Fgenerated-state-001-baseline-uncontainerized-parity) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-001-baseline-uncontainerized-parity...code%2Fgenerated-state-002-edge-proxy-uncontainerized) |
| Next | `003-agentic-harness-foundation` | [code/generated-state-003-agentic-harness-foundation](https://github.com/finos/traderX/tree/code%2Fgenerated-state-003-agentic-harness-foundation) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-002-edge-proxy-uncontainerized...code%2Fgenerated-state-003-agentic-harness-foundation) |

State sets:
- Previous states: `001-baseline-uncontainerized-parity`
- Next states: `003-agentic-harness-foundation`

## Convergence Status

- Convergence state: `false`
- Convergence level: `none`
- Lineage role: `prelude`
- Dotted-line parents: `none`
- Previous convergence milestone: `none`
- Next convergence milestone: [004-containerized-compose-runtime](https://github.com/finos/traderX/tree/code%2Fgenerated-state-004-containerized-compose-runtime) (🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-002-edge-proxy-uncontainerized...code%2Fgenerated-state-004-containerized-compose-runtime))

### Convergence Neighborhood

```mermaid
flowchart LR
  C_CUR["002-edge-proxy-uncontainerized (current)"]
  style C_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  C_CUR --> C_NEXT_004_containerized_compose_runtime["004-containerized-compose-runtime"]
  click C_NEXT_004_containerized_compose_runtime href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-004-containerized-compose-runtime" "Open branch"
  %% compare: https://github.com/finos/traderX/compare/code%2Fgenerated-state-002-edge-proxy-uncontainerized...code%2Fgenerated-state-004-containerized-compose-runtime
  click C_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-002-edge-proxy-uncontainerized" "Open current branch"
```

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-state-002-edge-proxy-generated.sh
```

```powershell
./scripts/start-state-002-edge-proxy-generated.ps1
```

Browser endpoint (via edge proxy): `http://localhost:18080`

Status / stop:

```bash
./scripts/status-state-002-edge-proxy-generated.sh
./scripts/stop-state-002-edge-proxy-generated.sh
```

```powershell
./scripts/status-state-002-edge-proxy-generated.ps1
./scripts/stop-state-002-edge-proxy-generated.ps1
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

- Feature pack: `specs/002-edge-proxy-uncontainerized`
- Generation entrypoint: `bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized`
- Developer learning guide for this snapshot: [LEARNING.md](./LEARNING.md)
- Functional validation guide: [FUNCTIONAL_TESTING.md](./FUNCTIONAL_TESTING.md)
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Source commit: https://github.com/finos/traderX/commit/0313dc7bf828e4933b788834802bda10b8200bf5
- Feature pack at source commit: https://github.com/finos/traderX/tree/0313dc7bf828e4933b788834802bda10b8200bf5/specs/002-edge-proxy-uncontainerized
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/0313dc7bf828e4933b788834802bda10b8200bf5/docs/spec-kit
