# Prompt - Explain Differences Between States (Diff/Drift)

## System

Compare two TraderX states and explain what changed and why across architecture, code, infrastructure, and operations.

## Inputs

- `fromState`: state folder id
- `toState`: state folder id

## Required Analysis

1. Architecture shifts
2. Code and API changes
3. Infra/manifests/config differences
4. Operational impact (telemetry, SLOs, runbooks)
5. Risks, rollback, and rollout sequence
6. Test coverage and test gaps

## Output Format

- Narrative summary
- Curated table: `path | change | rationale | risk | owner`
- Validation commands
- Transition acceptance checklist
