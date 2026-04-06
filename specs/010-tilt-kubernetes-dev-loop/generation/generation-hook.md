# Generation Hook: 010-tilt-kubernetes-dev-loop

- Hook script: `pipeline/generate-state-010-tilt-kubernetes-dev-loop.sh`
- Feature pack: `specs/010-tilt-kubernetes-dev-loop`

Patch-set model:

- Parent state: `009-kubernetes-runtime`
- Patch path: `specs/010-tilt-kubernetes-dev-loop/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `004`.
2. Apply state patch set (Tilt assets + k8s dev-loop artifacts).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 010-tilt-kubernetes-dev-loop 009-kubernetes-runtime
```
