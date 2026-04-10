# Implementation Plan: 003-agentic-harness-foundation

## Scope

- Transition from `002-edge-proxy-uncontainerized` to `003-agentic-harness-foundation`.
- Keep runtime behavior unchanged from state `002`.
- Add minimal generated-code harness artifacts and contribution contract.

## Deliverables

1. State spec pack with explicit harness contract.
2. Generation hook for state `003` that reuses state `002` runtime output.
3. Runtime scripts for state `003` wrappers and smoke tests.
4. Generated harness artifact creation in pipeline (`AGENTS.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`).
5. Catalog/docs updates so this state is in the canonical lineage before state `004` (containerized baseline).

## Exit Criteria

- State `003` is marked implemented in catalog with correct lineage.
- Harness files appear in generated output and read correctly.
- Existing state generation and publishing flows remain green after renumbering.
