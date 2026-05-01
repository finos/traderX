# 001 Simple App - Base Uncontainerized App

This is the canonical root Spec Kit feature pack for the TraderX simple base app in uncontainerized mode.

## Primary Artifacts

- `spec.md` - plain-English user stories and FR/NFR requirements
- `plan.md` - technical implementation plan
- `tasks.md` - execution checklist
- `fidelity-profile.md` - technical shape/closeness policy
- `contracts/**` - baseline API contracts
- `system/**` - normalized system requirements/story/traceability artifacts used by generation pipelines, including generated architecture docs from `system/architecture.model.json`
- `components/**` - per-component requirement coverage
- `conformance/**` - generated per-component conformance packs
- `tests/smoke/**` - state smoke-test coverage expectations

## Environment Lifecycle Contract

Every uncontainerized generated state must provide and maintain these four scripts:

- `scripts/start-<state>.sh --build-only` - install dependencies and compile artifacts; never starts processes; reruns safely
- `scripts/start-<state>.sh` - start all services; requires a prior successful build
- `scripts/stop-<state>.sh` - stop all services; idempotent
- `scripts/smoke-test-<state>.sh` - end-to-end readiness check against a running environment; read-only; exits `0` only when healthy

The smoke test is the canonical "ready for business" check and must remain runnable independently from the start script.

## Validation

```bash
bash pipeline/speckit/validate-speckit-readiness.sh
bash pipeline/speckit/verify-spec-expressiveness.sh
bash pipeline/speckit/run-all-conformance-packs.sh
```
