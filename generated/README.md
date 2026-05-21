# Generated Artifacts

This directory is intentionally ephemeral and gitignored.

Current layout:

- `generated/code/components/` - per-component generated source outputs
- `generated/code/target-generated/` - assembled runnable baseline workspace
- `generated/manifests/` - synthesized component generation manifests
- `generated/api-docs/` - Docusaurus OpenAPI docs output

Regenerate from repo root using:

```bash
bash pipeline/generate-from-spec.sh
```
