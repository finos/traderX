# Generation Hook: 011-tilt-kubernetes-dev-loop

- Hook script: `pipeline/generate-state-011-tilt-kubernetes-dev-loop.sh`
- Feature pack: `specs/011-tilt-kubernetes-dev-loop`

Patch-set model:

- Parent state: `010-kubernetes-runtime`
- Patch path: `specs/011-tilt-kubernetes-dev-loop/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `010`.
2. Apply state patch set (Tilt assets + k8s dev-loop artifacts).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 011-tilt-kubernetes-dev-loop 010-kubernetes-runtime
```
