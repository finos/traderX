# Custom Overlay Template (Bootstrap)

This template is the canonical starter for custom TraderX overlays.

It includes reference stubs for key contracts:

- `overlay/transforms/apply-feature-example.sh`
- `overlay/transforms/apply-managed-postgres-endpoint-example.sh`
- `overlay/transforms/apply-internal-docs-banner-example.sh`
- `overlay/runtime/env-loader.sh`
- `overlay/profiles/custom-internal.example.yaml`
- `overlay/catalog/sanctioned-learning-graph.example.yaml`
- `overlay/catalog/learning-graph-diagram.example.md`
- `overlay/docs/internal-learning-graph.example.md`
- `overlay/docs/internal-docs-portal.example.md`
- `pipeline/publish-state-branch.sh`

Use these as patterns when implementing your own overlay-specific generation and publishing workflows.

## Internal Docs + Sanctioned Graph Pattern

The included example docs and profile files show how to:

- suppress selected upstream states in controlled environments
- define internal-only generated states (`custom-*`)
- publish a sanctioned internal learning graph
- implement a required convergence diagram and state-to-artifact table in `docs/learning/index.md`
- add a persistent internal-distribution banner to an internal docs portal

## Docs Quality Checks (Optional)

For overlay docs portals, run AFDocs against local preview and published URLs:

```bash
npx afdocs check http://localhost:<PORT_FOR_DOCUSAURUS> --format scorecard
npx afdocs check http://localhost:<PORT_FOR_DOCUSAURUS> --format json --score
npx afdocs check https://docs.example.com --format scorecard
```
