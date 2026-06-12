# Research: Docs Portal Homepage

## Decision: Keep Homepage Data Catalog-Backed

The homepage should import repository metadata directly at Docusaurus build time.

Rationale:

- `catalog/state-catalog.json` already owns generated state identity, status, lineage, feature-pack paths, and publish branches.
- `catalog/live-environments.json` already owns public demo names, URLs, and state bindings.
- Duplicating this data in React components would cause stale homepage cards when states or demo URLs change.

## Decision: Keep Homepage Outside Generated-State Catalog

The homepage should have a root feature pack but should not be added to `catalog/state-catalog.json`.

Rationale:

- The state catalog represents generated runtime architecture states.
- The homepage is a Docusaurus portal feature that presents those states.
- `specs/README.md` separates generated state feature packs from portal feature packs to preserve catalog parity checks.

## Decision: Componentize the HTML Prototype

The standalone `new_website/traderx.html` prototype should be replaced by React components in the Docusaurus app.

Rationale:

- Docusaurus routing, links, build checks, and static asset handling should own the canonical homepage.
- Component boundaries make future copy, data, and interaction changes easier to review.

## Open Follow-Up

The runtime-doc link currently uses `end-to-end-flows` for state `001` and `runtime-topology` for later states. If future states need different runtime documentation targets, add explicit route metadata to `catalog/state-catalog.json` instead of growing homepage exceptions.
