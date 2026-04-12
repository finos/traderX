# Generation Hook: 003-agentic-harness-foundation

- Hook script: `pipeline/generate-state-003-agentic-harness-foundation.sh`
- Feature pack: `specs/003-agentic-harness-foundation`

This state is a no-patch transition that reuses parent runtime output and relies on
runtime harness installation to inject generated repository metadata files.

## Hook Responsibilities

1. Generate parent state `002-edge-proxy-uncontainerized`.
2. Regenerate state architecture docs from this state pack.
3. Emit deterministic summary metadata.
4. Do not mutate runtime service code paths relative to state `002`.
5. Enforce sequential generation for shared output roots; concurrent runs are only valid when each run uses a unique `TRADERX_GENERATED_ROOT`.
6. Synchronize Node lockfiles with generated manifests, refreshing only when `package.json` changes or lockfiles are missing/invalid.
7. Sync canonical Gradle wrapper assets into generated Gradle modules so wrapper artifacts remain template-owned and patch-independent.
8. Ensure state patch capture excludes build/restored output directories so patchsets remain authored deltas and avoid generated artifact drift.
