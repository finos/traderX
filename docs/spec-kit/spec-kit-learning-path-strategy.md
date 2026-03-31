# SpecKit Learning Path Strategy

This page defines how TraderX learning paths evolve from the same baseline using GitHub SpecKit artifacts in `specs/` and `.specify/`.

The model supports both parallel tracks and intentionally conflicting architectural choices, while preserving explicit lineage between states.

## Transition Model

Each learning-path transition is modeled as a separate spec feature branch:

1. Keep `001-baseline-uncontainerized-parity` as the stable base.
2. Create a new feature spec for one state transition only (for example, add containerization or add ingress).
3. Capture new or changed functional requirements only where behavior changes.
4. Layer non-functional requirements for platform, security, operability, and performance goals.
5. Generate and validate code for that transition against the previous accepted state.

Current published baseline progression:

- `001-baseline-uncontainerized-parity`
- `002-edge-proxy-uncontainerized`
- `003-containerized-compose-runtime`

Current branch tracks from `003`:

- DevEx track: `004-kubernetes-runtime` -> (`005-radius-kubernetes-platform` | `006-tilt-kubernetes-dev-loop`)
- Architecture track: `007-messaging-nats-replacement` (planned implementation)

## Candidate Next Architecture Step

One planned learning-path candidate is adopting CALM as architecture modeling input:

- CALM reference: [https://calm.finos.org](https://calm.finos.org)
- Expected transition shape:
  - add CALM architecture artifacts per state,
  - map CALM model deltas to state requirements,
  - regenerate state architecture docs and implementation with traceability.

## Required Artifacts Per Transition

- `spec.md`: user stories, acceptance criteria, and explicit in-scope change.
- `plan.md`: technical approach, interfaces, runtime model, and rollout notes.
- `tasks.md`: ordered implementation tasks and verification tasks.
- contracts updates (`contracts/**`) only for interface changes.
- traceability updates when requirements or stories move.

## Generation and Validation Loop

1. Update specs first.
2. Regenerate affected components.
3. Run conformance pack and parity checks.
4. Run state verification scripts for the target learning-path state.
5. Promote the transition only after docs and runtime checks pass.

## Publish Code Snapshots Per State

After a state passes validation, publish a generated-code snapshot branch:

```bash
bash pipeline/publish-generated-state-branch.sh <state-id> --push
```

State lineage and branch conventions are tracked in `catalog/state-catalog.json`.

This keeps each learning step reproducible, reviewable, and reversible while preserving a clean baseline lineage.
