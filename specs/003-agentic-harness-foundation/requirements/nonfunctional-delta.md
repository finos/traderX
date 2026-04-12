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
- Generated Node lockfiles must stay synchronized with current generated `package.json` content; refresh lockfiles only when manifests change or lockfiles are missing/invalid.
- Generated Gradle modules must receive wrapper assets from the canonical template baseline so wrapper version changes are centralized and inherited across all states.
- Default generated-branch build/test CI must be hermetic: tests in default suites must not require external databases or network services. Database-backed default tests must use in-memory/embedded engines; external database validation belongs in explicit integration test profiles/jobs.
- Generated-state publish flows must run compilation preflight over generated Node.js, Gradle, and .NET modules and fail prior to commit/push when preflight fails; bypass is allowed only via explicit operator override.
- For any downstream jump-point state that materializes full runtime module files (rather than directly reusing template paths), patch-owned files must preserve inherited base-template dependency/security controls unless an explicit state requirement declares a divergence.
- State patch capture must exclude build/restored output directories (`.gradle`, `build`, `target`, `bin`, `obj`, `dist`, `coverage`, `node_modules`) so generated-state diffs stay minimal and reproducible.
