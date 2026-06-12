# Feature Specification: Docs Portal Homepage

**Feature Branch**: `015-docs-portal-homepage`  
**Created**: 2026-06-12  
**Status**: Draft  
**Input**: Replace the default Docusaurus homepage with the TraderX reference architecture portal homepage, derived from SpecKit metadata.

## User Stories

- As a learner, I want the homepage to explain TraderX as a spec-driven financial-services reference architecture portal so I can orient quickly.
- As a developer, I want every generated state card to link to its spec, architecture, runtime documentation, learning guide, and generated code branch.
- As a maintainer, I want homepage state and demo data sourced from repository catalogs so the homepage does not drift from generated states.
- As a demo operator, I want live demo links to come from the live-environment registry so public demo URLs remain accurate.
- As an architect, I want the homepage to connect the state catalog to the learning graph so I can navigate from portal overview to deeper dependency/learning material.
- As an accessibility user, I want compact homepage actions to remain keyboard accessible and understandable by screen readers.

## Functional Requirements

- FR-01501: The Docusaurus root route `/` SHALL render the TraderX docs portal homepage instead of the previous default homepage.
- FR-01502: The homepage SHALL be implemented as React components under `website/src/components/homepage/**`, with `website/src/pages/index.js` acting only as the page entrypoint.
- FR-01503: The homepage SHALL derive the generated-state list from `catalog/state-catalog.json` and SHALL NOT duplicate state IDs, titles, status, tracks, publish branches, or feature-pack paths in static component data.
- FR-01504: Each generated state displayed on the homepage SHALL expose links to its feature spec, generated architecture documentation, runtime or end-to-end flow documentation, learning guide, and generated code branch.
- FR-01505: If a state catalog entry declares a decision record, the corresponding homepage state actions SHALL include a link to that ADR.
- FR-01506: The homepage SHALL group generated states by catalog track so new states can appear in the appropriate portal section without editing rendered card content.
- FR-01507: Live demo cards SHALL be derived from `catalog/live-environments.json` and joined to `catalog/state-catalog.json` by `stateId`.
- FR-01508: Live demo links SHALL use the exact URL values from `catalog/live-environments.json`; for the advanced demo this currently means `https://demo-advanced.traderx.finos.org`.
- FR-01509: The hero SHALL describe TraderX as a spec-driven reference architecture portal, not as a one-time transformation status.
- FR-01510: The Knowledge Graph reference in the hero SHALL link to `/docs/learning-paths`.
- FR-01511: The top navigation logo SHALL use the TraderX icon asset from `static/img`, and the hero brand mark SHALL use the primary TraderX horizontal logo asset from `static/img`.
- FR-01512: The footer SHALL make only source claims that are true for the current implementation and SHALL identify the catalog-backed source for homepage state data.
- FR-01513: Homepage state-card actions SHALL use compact gray icon buttons with hover/focus tooltips rather than verbose repeated text labels.
- FR-01514: The homepage SHALL include audience-oriented copy for developers, platform teams, architects, and sponsors learning financial-services architecture through runnable reference states and SDD-enabled demos.
- FR-01515: The homepage SHALL describe the FINOS hackathon reinvention value proposition: sophisticated financial-services demos assembled in hours, not days, through SDD.
- FR-01516: The Spec-Driven Development homepage section SHALL use examples that explain specs, generated states, and internal overlays rather than unrelated application implementation snippets.
- FR-01517: The homepage SHALL explain that companies can customize internal learning journeys through overlays while preserving traceability to core TraderX requirements.
- FR-01518: The homepage SHALL use the actual FINOS logo asset in the footer instead of plain FINOS text and SHALL expose FINOS association in the top navigation.
- FR-01519: The top navigation brand label SHALL read `FINOS TraderX`.
- FR-01520: The homepage footer copyright SHALL name `Fintech Open Source Foundation`.
- FR-01521: The `What is Spec Kit?` homepage section SHALL link to the official Spec Kit docs, quickstart, and GitHub repository.

## Non-Functional Requirements

- NFR-01501: Homepage state and demo rendering must remain deterministic at build time so `cd website && npm run build` catches broken imports and route references.
- NFR-01502: Internal links must use Docusaurus routing primitives where applicable so base-url handling remains correct.
- NFR-01503: External generated-code and live-demo links must open safely with `target="_blank"` and `rel="noreferrer"`.
- NFR-01504: Icon-only actions must include accessible names through `aria-label`, native `title`, and visible focus treatment.
- NFR-01505: Homepage copy and data-source claims must avoid implying that static marketing content is generated from SpecKit unless that content is actually catalog or metadata driven.
- NFR-01506: The implementation must preserve Docusaurus build compatibility without adding a separate homepage runtime service.
- NFR-01507: Homepage styling must be responsive across desktop and mobile and must avoid overlapping text, clipped action buttons, or layout shifts caused by dynamic state data.

## Acceptance Scenarios

### Scenario 1: Visitor Opens Portal Root

Given the Docusaurus website is running  
When a visitor opens `/`  
Then the TraderX portal homepage renders with the TraderX logo, reference-portal pill, hero navigation, overview sections, catalog state sections, live demo cards, and footer.

### Scenario 2: State Catalog Changes

Given a new generated state is added to `catalog/state-catalog.json` with a feature pack and publish branch  
When the website is rebuilt  
Then the homepage state sections include that state without duplicating its metadata in component data.

### Scenario 3: Demo Registry Changes

Given a live demo URL changes in `catalog/live-environments.json`  
When the website is rebuilt  
Then the corresponding homepage demo card uses the updated URL.

### Scenario 4: State Card Navigation

Given a generated state card is visible  
When a user activates its spec, architecture, runtime, learning, ADR, or code icon action  
Then the user reaches the corresponding canonical repository artifact or generated branch URL.

### Scenario 5: Accessibility of Compact Actions

Given a keyboard or screen-reader user reaches a state-card action  
When the action receives focus  
Then the control exposes an accessible label and visible focus state that identifies the destination.

## Success Criteria

- SC-01501: `cd website && npm run build` succeeds with the new homepage and spec pack included.
- SC-01502: The rendered homepage state count matches `catalog/state-catalog.json.states.length`.
- SC-01503: The rendered live demo count matches `catalog/live-environments.json.environments.length`.
- SC-01504: State action URLs are computed from catalog fields and feature-pack paths rather than duplicated literal state metadata.
- SC-01505: The homepage footer accurately names `catalog/state-catalog.json` as the source for the state list.
- SC-01506: The visual learning graph route is reachable from the hero Knowledge Graph link.
- SC-01507: The SDD section includes a core requirements example, an internal overlay example, and copy that connects generated demos back to reviewed specs.
