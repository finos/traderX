# Implementation Plan: 006-tilt-kubernetes-dev-loop

## Scope

- Transition from `004-kubernetes-runtime` to `006-tilt-kubernetes-dev-loop`.
- Track focus: `devex`.
- Define requirement deltas and generation/test hooks.

## Deliverables

1. Requirement deltas in `requirements/`.
2. Contract deltas in `contracts/`.
3. Architecture and topology deltas in `system/`.
4. Generation hook implementation in `pipeline/generate-state-006-tilt-kubernetes-dev-loop.sh`.
5. Smoke test implementation in `scripts/test-state-006-tilt-kubernetes-dev-loop.sh`.

## Exit Criteria

- Spec and tasks are complete and reviewed.
- Generation hook produces expected artifacts.
- Smoke tests pass for this state.
- State can be published to `code/generated-state-006-tilt-kubernetes-dev-loop`.
