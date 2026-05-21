# Generation Hook: 012-platform-convergence-c3

- Hook script: `pipeline/generate-state-012-platform-convergence-c3.sh`
- Feature pack: `specs/012-platform-convergence-c3`

Patch-set model:

- Parent state: `011-tilt-kubernetes-dev-loop`
- Patch path: `specs/012-platform-convergence-c3/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `011`.
2. Apply state patch set (convergence metadata artifacts).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 012-platform-convergence-c3 011-tilt-kubernetes-dev-loop
```
