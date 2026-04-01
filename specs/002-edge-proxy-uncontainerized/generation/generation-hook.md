# Generation Hook: 002-edge-proxy-uncontainerized

- Hook script: `pipeline/generate-state-002-edge-proxy-uncontainerized.sh`
- Feature pack: `specs/002-edge-proxy-uncontainerized`

This state uses a component-level patch set overlay.

- Parent state: `001-baseline-uncontainerized-parity`
- Patch path: `specs/002-edge-proxy-uncontainerized/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/components`

Hook flow:

1. Generate parent baseline components.
2. Apply component patch set (adds edge-proxy + web env overlay).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh \
  002-edge-proxy-uncontainerized \
  001-baseline-uncontainerized-parity \
  generated/code/components
```
