---
title: API Explorer
---

# API Explorer

TraderX now publishes interactive API reference docs in Docusaurus from the canonical OpenAPI contracts.

## Browse

- Explorer landing page: `/traderspec-specs/api`
- Source contracts: `specs/001-baseline-uncontainerized-parity/contracts/**/openapi.yaml`

## Regenerate API Docs

From repository root:

```bash
npm --prefix website run gen:api-docs
```

Then build/serve:

```bash
npm --prefix website run build
npm --prefix website run serve
```

## Plugin Stack

- `docusaurus-plugin-openapi-docs`
- `docusaurus-theme-openapi-docs`

Configured in:

- `website/docusaurus.config.js`
- `website/traderspec-api.sidebars.js`
