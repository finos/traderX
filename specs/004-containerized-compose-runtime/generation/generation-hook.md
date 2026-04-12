# Generation Hook: 004-containerized-compose-runtime

- Hook script: `pipeline/generate-state-004-containerized-compose-runtime.sh`
- Feature pack: `specs/004-containerized-compose-runtime`

This state uses a target-runtime patch set overlay.

- Parent state: `003-agentic-harness-foundation`
- Patch path: `specs/004-containerized-compose-runtime/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `003`.
2. Apply state patch set (compose assets + ingress + Dockerfiles).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh \
  004-containerized-compose-runtime \
  003-agentic-harness-foundation
```
