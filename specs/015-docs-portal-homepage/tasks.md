# Tasks: 015-docs-portal-homepage

- [x] T01501 Locate `new_website/traderx.html` and confirm the prototype content to preserve.
- [x] T01502 Replace the Docusaurus root homepage entry with a React component entrypoint.
- [x] T01503 Split homepage implementation into focused React components under `website/src/components/homepage/**`.
- [x] T01504 Import `catalog/state-catalog.json` into homepage data preparation.
- [x] T01505 Import `catalog/live-environments.json` into homepage data preparation.
- [x] T01506 Derive state spec, architecture, runtime/flow, learning, generated-code, and ADR links from catalog metadata.
- [x] T01507 Derive live demo cards from the live-environment registry and fix the advanced demo URL to `demo-advanced`.
- [x] T01508 Replace state-card text links with accessible gray icon actions and hover/focus tooltips.
- [x] T01509 Link the hero Knowledge Graph reference to `/docs/learning-paths`.
- [x] T01510 Use the TraderX icon asset for top navigation and the primary horizontal TraderX logo in the hero.
- [x] T01511 Update hero pill and audience copy to position TraderX as a spec-driven reference architecture portal.
- [x] T01512 Update footer copy so source claims match the catalog-backed implementation.
- [x] T01513 Define the homepage feature pack under `specs/015-docs-portal-homepage`.
- [x] T01514 Update the Spec Kit portal map to reference the homepage contract.
- [x] T01515 Run `tools/validate-frontmatter.sh`.
- [x] T01516 Run `bash pipeline/speckit/validate-root-spec-kit-gates.sh`.
- [x] T01517 Run `bash pipeline/speckit/validate-speckit-readiness.sh`.
- [x] T01518 Run `bash pipeline/verify-spec-coverage.sh`.
- [x] T01519 Run `cd website && npm run build`.
- [x] T01520 Smoke-test the homepage root route in a browser.
- [x] T01521 Add standard support artifacts required by spec coverage: `research.md`, `data-model.md`, `quickstart.md`, and `system/architecture.md`.
- [x] T01522 Replace SDD implementation snippets with spec, overlay, and generated-state workflow examples.
- [x] T01523 Add homepage copy that frames TraderX as a FINOS hackathon reinvention for sophisticated demos in hours, not days.
- [x] T01524 Update homepage spec and contract for SDD overlay/customization messaging.
- [x] T01525 Replace footer FINOS text with the FINOS logo asset and add top-nav FINOS association branding.
- [x] T01526 Change the top navigation brand label to `FINOS TraderX`.
- [x] T01527 Change footer copyright text to `Fintech Open Source Foundation`.
- [x] T01528 Link the footer catalog source note to `catalog/state-catalog.json`.
- [x] T01529 Add official Spec Kit docs, quickstart, and GitHub repository links to the `What is Spec Kit?` homepage section.
- [x] T01530 Remove the accidental top-nav pill styling from the Learning link and stabilize live-demo card link hover/default states.
- [x] T01531 Rename the live-environments docs link to `All demo environments`.
- [x] T01532 Add state-list-style icons to the demo card `State spec` and `Generated code` buttons.

## Dependency Notes

- T01504 and T01505 are prerequisites for keeping homepage content synchronized with generated states and live demos.
- T01506 is required before the homepage can replace the older Docusaurus homepage as a useful portal entry.
- T01513 and T01514 are required before treating the homepage as a SpecKit-maintained feature rather than a standalone HTML prototype.
