---
title: API Explorer
---

# API Explorer

TraderX now publishes interactive API reference docs in Docusaurus from the canonical OpenAPI contracts.

The explorer is intentionally state-scoped. Today it represents the baseline contracts in `001-baseline-uncontainerized-parity`.

## Browse

- Explorer landing page: `/api` (state `001` scope)
- Source contracts: `specs/001-baseline-uncontainerized-parity/contracts/**/openapi.yaml`

## Regenerate API Docs

API docs are generated on demand when running docs start/build:

```bash
npm --prefix website run start
npm --prefix website run build
```

Manual explicit regeneration is also available:

```bash
npm --prefix website run gen:api-docs
```

Generated API docs are written to `generated/api-docs/**` and treated as ephemeral output.

## Plugin Stack

- `docusaurus-plugin-openapi-docs`
- `docusaurus-theme-openapi-docs`

Configured in:

- `website/docusaurus.config.js`
- `website/traderspec-api.sidebars.js`
