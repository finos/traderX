# Generation Hook: 003-containerized-compose-runtime

- Hook script: `pipeline/generate-state-003-containerized-compose-runtime.sh`
- Feature pack: `specs/003-containerized-compose-runtime`

This state uses a target-runtime patch set overlay.

- Parent state: `002-edge-proxy-uncontainerized`
- Patch path: `specs/003-containerized-compose-runtime/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `002`.
2. Apply state patch set (compose assets + ingress + Dockerfiles).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh \
  003-containerized-compose-runtime \
  002-edge-proxy-uncontainerized
```
