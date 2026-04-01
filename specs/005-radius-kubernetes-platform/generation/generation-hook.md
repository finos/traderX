# Generation Hook: 005-radius-kubernetes-platform

- Hook script: `pipeline/generate-state-005-radius-kubernetes-platform.sh`
- Feature pack: `specs/005-radius-kubernetes-platform`

Patch-set model:

- Parent state: `004-kubernetes-runtime`
- Patch path: `specs/005-radius-kubernetes-platform/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `004`.
2. Apply state patch set (Radius app model + workspace artifacts).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 005-radius-kubernetes-platform 004-kubernetes-runtime
```
