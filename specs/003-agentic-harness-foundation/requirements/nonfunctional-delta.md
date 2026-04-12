# Non-Functional Delta: 003-agentic-harness-foundation

Parent state: `002-edge-proxy-uncontainerized`

## Runtime / Operations

- Runtime startup, stop, and status behavior remain equivalent to state `002`.
- Generation runs that target the default shared output root (`generated/**`) must execute sequentially; parallel runs require distinct `TRADERX_GENERATED_ROOT` values per run.

## Security / Compliance

- Contribution policy reduces risk of untracked upstream drift by directing enhancements to spec-first source paths.
- Generated-branch CI baseline from state `002` remains required (`security.yml`, `license-scanning-node.yml`, and CVE suppression files aligned to component/dependency changes).

## Performance / Scalability

- No runtime performance impact; this state is documentation/harness-only.

## Reliability / Observability

- Idempotent harness generation avoids drift between repeated generation runs.
- Generation lock behavior must fail fast on concurrent shared-root runs to prevent partial/corrupt output snapshots.
- Generated Node lockfiles must be refreshed from current generated `package.json` content on each generation run to prevent stale dependency resolution drift across states.
- Generated Gradle modules must receive wrapper assets from the canonical template baseline so wrapper version changes are centralized and inherited across all states.
- For any downstream jump-point state that materializes full runtime module files (rather than directly reusing template paths), patch-owned files must preserve inherited base-template dependency/security controls unless an explicit state requirement declares a divergence.
- State patch capture must exclude build/restored output directories (`.gradle`, `build`, `target`, `bin`, `obj`, `dist`, `coverage`, `node_modules`) so generated-state diffs stay minimal and reproducible.
