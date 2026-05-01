# Generation Hook: 010-kubernetes-runtime

- Hook script: `pipeline/generate-state-010-kubernetes-runtime.sh`
- Feature pack: `specs/010-kubernetes-runtime`

Patch-set model:

- Parent state: `009-order-management-matcher`
- Patch path: `specs/010-kubernetes-runtime/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `009`.
2. Apply state patch set (k8s manifests, kind config, build plan).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 010-kubernetes-runtime 009-order-management-matcher
```
