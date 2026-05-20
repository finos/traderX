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
