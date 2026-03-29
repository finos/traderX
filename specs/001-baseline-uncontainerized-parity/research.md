# Research: Simple App - Base Uncontainerized App

## Inputs Reviewed

- `README.md` (manual local run order and port model)
- `docs/flows.md` (functional sequence flows F1-F6)
- `docs/overview.md` (component topology reference)
- Existing generated runtime scripts under `scripts/`
- Canonical baseline contracts under `specs/001-baseline-uncontainerized-parity/contracts/**`

## Key Decisions

1. Root-level Spec Kit structure (`.specify/`, `specs/NNN-*`) is now introduced and treated as canonical for new requirements work.
2. Baseline runtime remains pre-containerized with deterministic process order and explicit ports.
3. Contract compatibility remains mandatory through copied baseline OpenAPI snapshots under this feature's `contracts/`.
4. CORS remains a baseline non-functional requirement for cross-port UI-to-service traffic in pre-ingress mode.
5. Existing TraderSpec runtime and smoke scripts remain execution harness during migration to avoid destabilizing verified behavior.

## Risks

- Divergence risk between root `specs/` canonical artifacts and legacy `TraderSpec/speckit/` duplicates during transition.
- Branch naming mismatch risk with Spec Kit scripts when not on `NNN-*` branch (mitigated by `SPECIFY_FEATURE` override).
- Toolchain/network variability on developer workstations can impact reproducibility.

## Mitigations

- Use root feature packs as source of truth for new requirements updates.
- Synchronize or retire legacy duplicate docs in controlled phases.
- Keep script-based smoke and startup checks as mandatory evidence gates.
