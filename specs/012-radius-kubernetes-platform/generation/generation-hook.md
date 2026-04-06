# Generation Hook: 012-radius-kubernetes-platform

- Hook script: `pipeline/generate-state-012-radius-kubernetes-platform.sh`
- Feature pack: `specs/012-radius-kubernetes-platform`

Patch-set model:

- Parent state: `009-kubernetes-runtime`
- Patch path: `specs/012-radius-kubernetes-platform/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `004`.
2. Apply state patch set (Radius app model + workspace artifacts).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 012-radius-kubernetes-platform 009-kubernetes-runtime
```
