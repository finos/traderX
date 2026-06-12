# Implementation Plan: 015-docs-portal-homepage

## Scope

- Replace the Docusaurus root homepage with the TraderX reference architecture portal homepage.
- Convert the standalone HTML prototype into maintainable React components.
- Bind homepage state and live-environment sections to canonical repository metadata.
- Define the long-term homepage contract in this feature pack.

## Deliverables

1. Homepage React implementation:
   - `website/src/pages/index.js`
   - `website/src/components/homepage/TraderXHomepage.jsx`
   - `website/src/components/homepage/Hero.jsx`
   - `website/src/components/homepage/Tabs.jsx`
   - `website/src/components/homepage/Sections.jsx`
   - `website/src/components/homepage/Footer.jsx`
   - `website/src/components/homepage/Links.jsx`
   - `website/src/components/homepage/Icons.jsx`
   - `website/src/components/homepage/TraderXHomepage.module.css`
   - `website/src/components/homepage/homepageData.js`
2. Catalog-backed homepage data:
   - generated state cards from `catalog/state-catalog.json`
   - live demo cards from `catalog/live-environments.json`
   - per-state artifact links derived from feature-pack and publish metadata
3. SpecKit contract artifacts:
   - `README.md`
   - `spec.md`
   - `plan.md`
   - `tasks.md`
   - `system/homepage-contract.md`
4. Portal documentation update:
   - `docs/spec-kit/spec-kit-portal.md`

## Phased Execution

1. Phase A: Identify the standalone HTML prototype and current Docusaurus homepage entrypoint.
2. Phase B: Break the homepage into React components and CSS module styling.
3. Phase C: Replace static state/demo content with catalog-derived data.
4. Phase D: Add canonical navigation links for state specs, architecture, runtime docs, learning docs, generated code, and ADRs.
5. Phase E: Replace verbose state-card links with accessible icon actions.
6. Phase F: Align logo assets, hero copy, audience messaging, Knowledge Graph link, and footer source claims.
7. Phase G: Add this feature pack and portal documentation so future homepage changes have a maintaining spec.
8. Phase H: Run Docusaurus build and repository quality gates as available.

## Exit Criteria

- The homepage at `/` renders through the Docusaurus app, not through `new_website/traderx.html`.
- State and live-demo sections are driven from catalog files.
- Every visible state block has useful links to canonical specs, docs, learning material, and generated code.
- The homepage contract is documented in this feature pack and referenced from the Spec Kit portal map.
- Website build succeeds.
