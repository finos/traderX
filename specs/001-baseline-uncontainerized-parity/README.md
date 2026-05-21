# 001 Simple App - Base Uncontainerized App

![linux/mac support](https://badgen.net/badge/linux%2Fmac/supported/green?icon=linux) ![windows support](https://badgen.net/badge/windows/supported/green?icon=windows)

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
- `scripts/start-<state>.ps1 -BuildOnly` - PowerShell parity for build-only mode on supported states
- `scripts/start-<state>.ps1` - PowerShell parity for service start on supported states
- `scripts/stop-<state>.ps1` - PowerShell parity for stop flow on supported states
- `scripts/smoke-test-<state>.ps1` - PowerShell parity for smoke checks on supported states

The smoke test is the canonical "ready for business" check and must remain runnable independently from the start script.

## Validation

```bash
bash pipeline/speckit/validate-speckit-readiness.sh
bash pipeline/speckit/verify-spec-expressiveness.sh
bash pipeline/speckit/run-all-conformance-packs.sh
```

```powershell
pwsh -NoProfile -Command "bash pipeline/speckit/validate-speckit-readiness.sh"
pwsh -NoProfile -Command "bash pipeline/speckit/verify-spec-expressiveness.sh"
pwsh -NoProfile -Command "bash pipeline/speckit/run-all-conformance-packs.sh"
```
