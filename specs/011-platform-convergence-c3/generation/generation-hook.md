# Generation Hook: 011-platform-convergence-c3

- Hook script: `pipeline/generate-state-011-platform-convergence-c3.sh`
- Feature pack: `specs/011-platform-convergence-c3`

Patch-set model:

- Parent state: `009-kubernetes-runtime`
- Patch path: `specs/011-platform-convergence-c3/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `004`.
2. Apply state patch set (Tilt assets + k8s dev-loop artifacts).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 011-platform-convergence-c3 009-kubernetes-runtime
```
