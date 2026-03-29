---
title: API Explorer
---

# API Explorer

TraderX now publishes interactive API reference docs in Docusaurus from the canonical OpenAPI contracts.

## Browse

- Explorer landing page: `/api`
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

## Plugin Stack

- `docusaurus-plugin-openapi-docs`
- `docusaurus-theme-openapi-docs`

Configured in:

- `website/docusaurus.config.js`
- `website/traderspec-api.sidebars.js`
