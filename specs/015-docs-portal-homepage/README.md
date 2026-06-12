# Docs Portal Homepage

This feature pack defines the Docusaurus homepage that replaces the former default docs homepage and the standalone `new_website/traderx.html` prototype.

## Intent

The homepage is the front door for the TraderX reference architecture portal. It must present the generated state catalog, live demo environments, learning graph, and source artifacts directly from canonical repository metadata so the page stays synchronized with SpecKit-driven changes.

## Canonical Sources

- Generated state metadata: `catalog/state-catalog.json`
- Live demo registry: `catalog/live-environments.json`
- State feature packs: `specs/NNN-*`
- Learning graph index: `docs/learning-paths/index.md`
- Portal map: `docs/spec-kit/spec-kit-portal.md`

## Owned Surface

- Docusaurus root route: `/`
- React homepage components: `website/src/components/homepage/**`
- Docusaurus page entry: `website/src/pages/index.js`

## Out of Scope

- Generated runtime application changes
- Generated state branch snapshots
- State-catalog schema changes unrelated to homepage rendering
- Environment-specific overlays
