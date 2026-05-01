# Implementation Plan: 010-kubernetes-runtime

## Scope

- Transition from `004-containerized-compose-runtime` to `010-kubernetes-runtime`.
- Track focus: `devex`.
- Keep baseline functional behavior stable while changing runtime to Kubernetes.
- Generate deterministic Kind + Kubernetes assets from explicit state specs.

## Deliverables

1. Requirement and contract deltas under `requirements/` and `contracts/`.
2. Kubernetes runtime spec in `system/kubernetes-runtime.spec.json`.
3. NGINX edge proxy runtime config in `system/nginx-edge.conf`.
4. Architecture and topology deltas in `system/`.
5. Generation hook implementation in `pipeline/generate-state-010-kubernetes-runtime.sh`.
6. Runtime control scripts:
   - `scripts/start-state-010-kubernetes-runtime-generated.sh`
   - `scripts/start-state-010-kubernetes-runtime-generated.sh --skip-build`
   - `scripts/stop-state-010-kubernetes-runtime-generated.sh`
   - `scripts/status-state-010-kubernetes-runtime-generated.sh`
7. Smoke test implementation in `scripts/test-state-010-kubernetes-runtime.sh`.

## Exit Criteria

- Spec and tasks are complete and reviewed.
- Generation hook produces Kubernetes manifests and build plan artifacts deterministically.
- Start/status/stop scripts operate against local Kind runtime.
- Smoke tests pass for this state.
- State can be published to `code/generated-state-010-kubernetes-runtime`.
