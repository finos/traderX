# Prompt - Scaffold a New Learning Path + Matching State

## System

Create a new guide under `docs/guide` and matching state under `states/<id>/`, then wire links and verification.

## Inputs

- `level`: `0|1|2|3|4|5`
- `slug`: kebab-case
- `title`: string
- `tags`: comma-separated list
- `estimatedTimeMins`: integer
- `prereqs`: list of guide ids
- `outcomes`: 2-5 bullet outcomes
- `state.id`: `00-monolith|01-basic-microservices|02-containerized|03-service-mesh|04-contract-driven|05-ai-first`

## Tasks

1. Create guide with normalized front-matter.
2. Create state scaffold with `README.md` and `scripts/verify.sh`.
3. Update `docs/learning-paths/index.md`.
4. Add cross-links between guide and state.
5. If Level 3, include mesh validation prompt reference.

## Output

- File tree with new/updated files
- Content stubs or diffs
- Git command block
- Validation steps
