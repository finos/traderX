# Generation Hook: 004-kubernetes-runtime

- Hook script: `pipeline/generate-state-004-kubernetes-runtime.sh`
- Feature pack: `specs/004-kubernetes-runtime`

This state is expected to implement generation in the hook script above.

Minimum hook responsibilities:

1. Generate or transform code artifacts for this state.
2. Keep compatibility with state lineage contracts unless explicitly changed.
3. Produce deterministic output suitable for branch publishing.
