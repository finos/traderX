# SpecKit Learning Path Strategy

This page defines how TraderX learning paths evolve from the same baseline using GitHub SpecKit artifacts in `specs/` and `.specify/`.

## Transition Model

Each learning-path transition is modeled as a separate spec feature branch:

1. Keep `001-baseline-uncontainerized-parity` as the stable base.
2. Create a new feature spec for one state transition only (for example, add containerization or add ingress).
3. Capture new or changed functional requirements only where behavior changes.
4. Layer non-functional requirements for platform, security, operability, and performance goals.
5. Generate and validate code for that transition against the previous accepted state.

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

This keeps each learning step reproducible, reviewable, and reversible while preserving a clean baseline lineage.
