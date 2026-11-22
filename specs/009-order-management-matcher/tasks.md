# Tasks: 009-order-management-matcher

- [x] T01301 Define functional deltas in `requirements/functional-delta.md`.
- [x] T01302 Define non-functional deltas in `requirements/nonfunctional-delta.md`.
- [x] T01303 Document research and constraints in `research.md`.
- [x] T01304 Define data model impacts in `data-model.md`.
- [x] T01305 Author run instructions in `quickstart.md`.
- [x] T01306 Define contract deltas in `contracts/contract-delta.md`.
- [x] T01307 Update `system/architecture.model.json` and regenerate architecture docs.
- [ ] T01308 Implement generated runtime/code patchset for order management and matcher components.
- [ ] T01309 Add order-specific observability dashboards and Prometheus target config in generated runtime.
- [ ] T01310 Implement smoke tests: `scripts/test-state-009-order-management-matcher.sh`.
- [ ] T01311 Validate docs/spec gates and publish generated snapshot branch.
- [ ] T01312 Generate `runtime/deploy/aws-ec2-compose/` deployment bundle for this state (`demo-advanced` target profile) with dry-run-capable scripts and runbook.
- [ ] T01313 Validate deployment bundle local dry-run and enforce no hardcoded secrets/token material in generated deployment artifacts.
- [ ] T01314 Ensure generated deployment-bundle policy remains state-scoped: present for this containerized state, absent for uncontainerized states.
- [x] T01315 Diagnose demo-advanced without replacing runtime or exposing environment secrets (#487).
- [ ] T01316 Validate rebuilt infrastructure and maintained log collection with preserved dashboard labels.
- [ ] T01317 Preserve/backup PostgreSQL data, publish one replacement snapshot and complete exact-snapshot checks.
- [ ] T01318 Deploy the cleared snapshot and verify trading, persistence and observability; retain PR evidence.
- [x] T01319 Implement Market Order support with STP immediate execution and UI toggle (#481).
- [x] T01320 Hardened review updates: PostgreSQL schema parity, admin grid partial-fill actions and safety guards, and fail-fast patch automation (#495).

- [x] T01321 Preserve existing PostgreSQL orders through an atomic, repeatable pre-Hibernate MARKET schema upgrade.
- [x] T01322 Add executable Java matcher and PostgreSQL fresh/upgrade regression tests, document their runner, and run them in booking-durability CI.

- [x] T01323 Define NFR-01323 and state-local, implementation-independent durable-order conformance for descendants and corporate adapters.
- [x] T01324 Implement and export the shared HTTP conformance runner and reference adapter; execute it through the state-009 regression CI command.
