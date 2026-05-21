# Implementation Plan: 014-fdc3-intent-interoperability

## Scope

- Transition from `012-platform-convergence-c3` to `014-fdc3-intent-interoperability`.
- Track focus: `functional`.
- Deliver a frontend-led FDC3 interoperability layer without changing baseline backend service contracts.
- Deliver a local Sail sidecar runtime for repeatable demos.

## Deliverables

1. Requirements and constraints finalized in:
   - `requirements/functional-delta.md`
   - `requirements/nonfunctional-delta.md`
   - `contracts/contract-delta.md`
2. Supporting design artifacts:
   - `research.md`
   - `data-model.md`
   - `system/runtime-topology.md`
   - `system/architecture.model.json` and generated `system/architecture.md`
3. Frontend interop implementation in generated state overlay (Angular):
   - FDC3 bootstrap and agent capability detection
   - context mapper utilities (trade/order/position -> `fdc3.instrument`)
   - inbound context listeners and intent listeners
   - outbound intent/action wiring in relevant UI controls
4. Local Sail sidecar packaging:
   - container/runtime definition for Sail web mode
   - seeded app-directory overlays including TraderX record + selected demo apps
   - state start/status/stop integration for Sail lifecycle management
5. Automated verification:
   - unit tests for mapping/listener logic
   - integration tests with a mocked DesktopAgent
   - optional demo E2E checks against local Sail profile
6. Generation/test hooks:
   - `pipeline/generate-state-014-fdc3-intent-interoperability.sh`
   - `scripts/test-state-014-fdc3-intent-interoperability.sh`

## Phased Execution

1. Phase A: Build shared interop primitives (agent access, mapping, availability/degraded mode).
2. Phase B: Implement outbound context + outbound intent actions from TraderX views.
3. Phase C: Implement inbound context + inbound intent handling (including custom ticket intents).
4. Phase D: Implement local Sail sidecar runtime and app-directory seeding.
5. Phase E: Add metadata declarations and complete test automation.
6. Phase F: Finalize render hook artifacts, run gates, and publish generated snapshot.

## Exit Criteria

- Spec, plan, and tasks are complete and reviewed.
- FDC3 behavior works in mocked integration tests and in local Sail demo profile.
- Smoke tests include FDC3 interoperability assertions and pass.
- Generated snapshot branch target is ready: `code/generated-state-014-fdc3-intent-interoperability`.
