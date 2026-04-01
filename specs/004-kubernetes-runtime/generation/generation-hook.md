# Generation Hook: 004-kubernetes-runtime

- Hook script: `pipeline/generate-state-004-kubernetes-runtime.sh`
- Feature pack: `specs/004-kubernetes-runtime`

Patch-set model:

- Parent state: `003-containerized-compose-runtime`
- Patch path: `specs/004-kubernetes-runtime/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `003`.
2. Apply state patch set (k8s manifests, kind config, build plan).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 004-kubernetes-runtime 003-containerized-compose-runtime
```
