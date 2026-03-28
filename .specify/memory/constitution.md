# TraderX Spec Constitution

## Core Principles

### I. Spec-First, Feature-Scoped
Every implementation change MUST originate from a feature directory under `specs/NNN-feature-name/` and its spec artifacts (`spec.md`, `plan.md`, `tasks.md`). Global ad-hoc requirement documents are not authoritative for implementation work.

### II. Contract-Locked Interoperability
For baseline flows, API/event contracts are mandatory compatibility boundaries. Changes that break currently approved contracts require explicit spec updates, impact analysis, and updated acceptance criteria before implementation.

### III. Deterministic Local Baseline
TraderX baseline behavior MUST remain reproducible on a developer workstation in uncontainerized mode with explicit startup order, fixed default ports, and scriptable readiness checks.

### IV. Evidence-Gated Delivery
A change is not complete until the mapped conformance/smoke checks pass and evidence is recorded in migration artifacts. Claims of parity without runnable evidence are invalid.

### V. Incremental Source Retirement
Legacy/hydrated paths are temporary bridge mechanisms only. They MUST be phased out component-by-component once generated implementations satisfy requirements, contracts, and runtime checks.

## Project Constraints

- Baseline UI scope is Angular for this migration stage.
- Baseline architecture spans Java/Spring, Node/Nest, Node/Socket.IO, .NET, H2, and Angular.
- Pre-ingress browser calls in baseline mode require explicit CORS support across cross-origin service calls.
- Generated outputs must remain runnable with local native toolchains (`gradle`, `npm`, `dotnet`) and existing TraderSpec scripts until root-level pipelines fully replace them.

## Workflow and Quality Gates

1. Create/maintain a numbered feature spec pack in `specs/`.
2. Ensure ambiguity resolution and checklist quality pass before implementation.
3. Produce/update technical plan and task breakdown tied to user stories.
4. Implement only tasks present in the active feature pack.
5. Run mapped validation (smoke, conformance, contract checks) and capture results.
6. Update migration TODO/blog with decisions and outcomes.

## Governance

This constitution supersedes local process conventions that conflict with Spec Kit methodology. Amendments require:
- an explicit spec update,
- migration impact notes,
- and approval in `TraderSpec/migration-todo.md` execution tracking.

**Version**: 1.0.0 | **Ratified**: 2026-03-28 | **Last Amended**: 2026-03-28
