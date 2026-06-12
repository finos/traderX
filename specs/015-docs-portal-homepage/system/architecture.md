# Architecture: Docs Portal Homepage

## Context

The homepage is a Docusaurus-rendered React page at `/`. It presents TraderX as a spec-driven reference architecture portal and routes visitors into generated state specs, learning material, live demos, and generated code branches.

## Components

```text
website/src/pages/index.js
  -> website/src/components/homepage/TraderXHomepage.jsx
     -> Hero.jsx
     -> Tabs.jsx
     -> Sections.jsx
     -> Footer.jsx
     -> Links.jsx
     -> Icons.jsx
     -> homepageData.js
     -> TraderXHomepage.module.css
```

## Build-Time Data Flow

```text
catalog/state-catalog.json
        |
        v
homepageData.js ----> phase groups ----> state cards ----> state artifact actions

catalog/live-environments.json
        |
        v
homepageData.js ----> joined environment cards ----> live demo links
```

## Runtime Behavior

- Docusaurus serves the homepage from `/`.
- Users can switch homepage tabs client-side.
- Internal routes use Docusaurus links.
- External demo and generated-code routes use normal anchors with safe external-link attributes.

## Integration Points

- Spec routes under `/specs/**`
- Learning graph route under `/docs/learning-paths`
- Learning guide routes under `/docs/learning/state-*`
- Live demo URLs from `catalog/live-environments.json`
- Generated code branches on GitHub from `catalog/state-catalog.json.states[].publish.branch`

## Failure Modes

- If a catalog entry lacks `featurePack`, the homepage cannot derive canonical spec routes for that state.
- If a catalog entry lacks `publish.branch`, the generated-code action cannot be derived.
- If a live environment references an unknown `stateId`, the homepage should still render the environment but should expose the missing state binding during development.

## Constraints

- Do not add a custom homepage service.
- Do not hand-maintain state or demo copies in component arrays.
- Do not claim generated provenance for curated copy.
