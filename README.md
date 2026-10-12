[![FINOS Hosted Platform - TraderX demo 004](https://img.shields.io/badge/FINOS%20Hosted%20Platform-TraderX%20Demo%20004-blue)](https://demo.traderx.finos.org/)
[![FINOS Hosted Platform - TraderX demo 009](https://img.shields.io/badge/FINOS%20Hosted%20Platform-TraderX%20Demo%20009-teal)](https://demo-advanced.traderx.finos.org/)
[![FINOS - Incubating](https://cdn.jsdelivr.net/gh/finos/contrib-toolbox@master/images/badge-incubating.svg)](https://finosfoundation.atlassian.net/wiki/display/FINOS/Incubating)

# FINOS | TraderX (SpecKit-First Baseline)

> This desk runs live for Colosseum Radar judges at
> **[colosseum.synapticchain.xyz](https://colosseum.synapticchain.xyz)** — clearinghouse console,
> nine-stage live-fire demo (`/demo`), Continuous Atomic Netting (`/can`), position brief (`/brief`),
> and milestone receipts (`/milestones`). Verification fast-path: [JUDGES_FLOW.md](https://github.com/Synaptics-Lab/synaptic-fx-terminal/blob/main/JUDGES_FLOW.md).

TraderX is now organized as a root-canonical GitHub SpecKit project.  
The baseline implementation is generated and validated from requirements, stories, acceptance criteria, contracts, and conformance gates.

## Canonical Project Layout

- `.specify/` - SpecKit constitution and templates
- `specs/001-baseline-uncontainerized-parity/` - baseline feature pack
- `pipeline/` + `scripts/` - generation, runtime, conformance, and parity orchestration
- `templates/` + `catalog/` - synthesis inputs and component/process catalogs
- `generated/` - generated runtime/code/docs artifacts workspace (ephemeral outputs)
- `docs/` + `website/` - documentation portal and API explorer
- `docs/learning/**` - developer-focused per-state learning guides for generated code snapshots

## Quickstart (Generated Baseline Runtime)

Generate baseline components:

```bash
bash pipeline/generate-state.sh 001-baseline-uncontainerized-parity
```

Start/stop/status:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh --build-only
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh

./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```

Run smoke tests:

```bash
./scripts/test-reference-data-overlay.sh
./scripts/test-database-overlay.sh
./scripts/test-people-service-overlay.sh
./scripts/test-account-service-overlay.sh
./scripts/test-position-service-overlay.sh
./scripts/test-trade-feed-overlay.sh
./scripts/test-trade-processor-overlay.sh
./scripts/test-trade-service-overlay.sh
./scripts/test-web-angular-overlay.sh
```

## Validation Gates

```bash
bash pipeline/speckit/validate-root-spec-kit-gates.sh
bash pipeline/speckit/validate-speckit-readiness.sh
bash pipeline/speckit/verify-spec-expressiveness.sh
bash pipeline/verify-spec-coverage.sh
bash pipeline/speckit/run-all-conformance-packs.sh
bash pipeline/speckit/run-full-parity-validation.sh
```

## Documentation

- SpecKit overview: `docs/spec-kit/index.md`
- Learning guides: `docs/learning/index.md`
- Learning paths: `docs/learning-paths/index.md`
- SpecKit portal: `docs/spec-kit/spec-kit-portal.md`
- Workflow: `docs/spec-kit/spec-kit-workflow.md`
- Runbook: `docs/spec-kit/spec-kit-generation-guide.md`
- Live environment registry: `docs/spec-kit/live-environments.md`
- EC2 host prerequisites: `docs/spec-kit/aws-ec2-compose-prerequisites.md`
- Legacy migration-era docs were retired from active tree; recover via git history if needed.

## Live Demos

- State `004`: [https://demo.traderx.finos.org](https://demo.traderx.finos.org)
- State `009`: [https://demo-advanced.traderx.finos.org](https://demo-advanced.traderx.finos.org)

## Learning Doc Enrichment Plugin

This repo uses the GitHub SpecKit ecosystem with optional community extension support for richer learning material workflows.

- Community extension used for learning-focused authoring experiments: `learn`
- Install command:

```bash
specify extension add learn --from https://github.com/imviancagrace/spec-kit-learn/archive/refs/tags/v1.1.0.zip
```

- Canonical committed learning docs stay under `docs/learning/**` and state feature packs under `specs/**`.

Live routes (Docusaurus):

- `/docs/spec-kit`
- `/docs/learning-paths`
- `/specs`
- `/specify`
- runtime API explorer: `/api/docs` (via running generated state ingress/edge)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Copyright 2023 UBS, FINOS, Morgan Stanley.

Distributed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
---

## Verification record — SynapticChain estate (2026-10-12)

Measured on the live tree (fresh grep census 2026-10-12); every live receipt below was
run twice unless noted.

- **3,347 Rust test functions** across the 23-crate L1 workspace (2,713 across 554 `.rs`
  files, 226,550 LOC — consensus 694, synaptic-types 373, state 299, compiler 247,
  p2p 221, node 220, vm 180) **plus** 634 across the estate's Rust service programs
  (CAN executor, Solana escrow program, verification suite, fuzz targets).
- **178 property-test macros** (`proptest`/`quickcheck`); `criterion` benchmark suites
  for consensus, node, and storage.
- **1,161 SDK test functions** (Python + TypeScript SDKs, 37 test files) and ~310 more
  across the gateway, terminal, and service suites — **>4,800 test
  functions/assertions platform-wide**.

| Suite | Score |
|---|---|
| Formal invariant verification (FIV v4.4) | 12/12 invariants PASS |
| FINOS Open Source Maturity Model | Level 5 — Grade A+ — 24/24 |
| Colosseum app preflight (edge-mode, strict TLS) | 21 PASS / 0 FAIL ×2 |
| finITe — FINOS conformance suite vs our agent | 131/132 ×2 (the 1 miss was a DOM-evaluation artifact of the harness itself, since resolved in CI) |
| Interledger devnet E2E (two-ledger loop) | 13/13 ×2 |
| FDC3 StartPayment → clearinghouse bridge | 15/15 ×2 |
| R15 MCP m2m corridors | 81/81 ×2 |
| R15 watermark rolling settlement | 24/24 ×2 |
| R13 multi-rail (Solana + XRPL mixed) phase 10 | 14/14 ×2 |
| Corridor 17 (sUSD/cTZS) | 24/24 ×2 |
| 10-stage live wire loop (FDC3 intent → clearinghouse seal → dual-rail evidence → margin settlement → finalize → outbound pacs.008 render) | ALL 11 stages GREEN ×2, 2026-10-12 (sessions 102/103 sealed; same-UETR pacs.008.001.08 rendered) |
| Uhuru/UTA audit battery | 17/17 ×2 (remediation + SSOT-frame); UTA-2026-10-03-003 verdict PASS-WITH-NOTES |
| Daily preflight + phase ladder (cron) | 2 GREEN pairs/day since 2026-10-08 |

Live consoles: [terminal.synapticchain.xyz](https://terminal.synapticchain.xyz) ·
[colosseum.synapticchain.xyz](https://colosseum.synapticchain.xyz). Full record in the
[Synaptic-Source README](https://github.com/Synaptics-Lab/Synaptic-Source).
