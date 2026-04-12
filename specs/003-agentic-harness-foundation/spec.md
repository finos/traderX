# Feature Specification: Agentic Harness Foundation

**Feature Branch**: `003-agentic-harness-foundation`  
**Created**: 2026-04-10  
**Status**: Implemented  
**Input**: Transition delta from `002-edge-proxy-uncontainerized`

## User Stories

- As a developer, I want each generated codebase to include clear agent guidance so local AI-assisted edits are safe and consistent.
- As a contributor, I want generated codebases to state that upstream enhancements must be made in spec packs, not directly in generated snapshots.
- As a maintainer, I want the harness contract to be inherited by later states without per-state duplication.

## Functional Requirements

- FR-00301: Generating this state must produce `AGENTS.md` in the generated codebase root.
- FR-00302: Generating this state must produce `ARCHITECTURE.md` in the generated codebase root.
- FR-00303: Generating this state must produce `CONTRIBUTING.md` in the generated codebase root.
- FR-00304: `CONTRIBUTING.md` must explicitly state that enhancement contributions belong in upstream specs/state packs, not in generated snapshot branches.
- FR-00305: Runtime behavior and smoke-test behavior from state `002-edge-proxy-uncontainerized` remain unchanged.

## Non-Functional Requirements

- NFR-00301: Harness artifact generation is deterministic and idempotent for repeated state generation runs.
- NFR-00302: Harness files must be concise and avoid duplicating existing generated runbook content.
- NFR-00303: States from `003` onward inherit the harness contract unless explicitly overridden.
- NFR-00304: State generation MUST run sequentially when using the default shared output root (`generated/**`) to avoid race conditions; parallel generation is only permitted when each run uses an isolated `TRADERX_GENERATED_ROOT`.
- NFR-00305: Node dependency lockfiles (`package-lock.json`) in generated outputs MUST remain synchronized with each module's current `package.json`; generation should refresh lockfiles only when manifests change or lockfiles are missing/invalid.
- NFR-00306: Gradle wrapper assets (`gradlew`, `gradlew.bat`, `gradle/wrapper/**`) MUST be template-owned baseline artifacts and must not be maintained in state patchsets.
- NFR-00307: State patchsets MUST exclude build/restored byproducts (`.gradle/**`, `build/**`, `target/**`, `bin/**`, `obj/**`, `dist/**`, `coverage/**`, `node_modules/**`) so patches remain authored deltas only.

## Success Criteria

- SC-00301: `bash pipeline/generate-state.sh 003-agentic-harness-foundation` produces a runnable output with the three harness files in target root.
- SC-00302: `scripts/test-state-003-agentic-harness-foundation.sh` passes and confirms parity with state `002` behavior.
- SC-00303: `pipeline/install-generated-runtime-harness.sh` applies harness files for `003+` states.
- SC-00304: A second concurrent invocation of `pipeline/generate-state.sh` against the same shared output root fails fast with a lock error instead of writing partial output.
