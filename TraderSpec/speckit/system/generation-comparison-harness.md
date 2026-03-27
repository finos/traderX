# Generation Comparison Harness

This harness compares generated component output between:

- a legacy git reference (`HEAD`, `origin/main`, or any commit-ish), and
- the current working tree generators.

It is used for phase 7.10 to classify output differences and keep synthesis migrations controlled.

## Commands

```bash
# Compare one component
bash TraderSpec/pipeline/speckit/compare-component-generation.sh trade-service HEAD

# Compare one component and allow differences (reports semantic categories)
bash TraderSpec/pipeline/speckit/compare-component-generation.sh trade-service HEAD --allow-differences

# Compare all generated components
bash TraderSpec/pipeline/speckit/compare-all-component-generation.sh HEAD --allow-differences
```

## Semantic Categories

When a diff exists, the harness buckets changed files into these categories:

- `source-code`
- `runtime-config`
- `api-contract`
- `build-tooling`
- `deployment-runtime`
- `seed-data`
- `branding-assets`
- `docs-spec`
- `other`

## Current Known Baseline Delta

The main expected recurring delta is under `docs-spec` for `SPEC.manifest.json` when only `generatedAtUtc` differs.
