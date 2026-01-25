# FINOS | TraderX Sample Trading App

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

TraderX is a simple, distributed reference application for exploring trading workflows in financial services. It is intentionally approachable and non-production, and is meant for education, experimentation, and demos.

## Start here
- [Overview](overview.md) for architecture and the C4-inspired diagram.
- [Flows](flows.md) for sequence diagrams of core user journeys.
- [Code map](code.md) for links to each service.
- The [Running TraderX](running.md) guide for run options (manual, Docker, Kubernetes/Tilt).

## What is in this docs folder
- `overview.md` contains the architectural diagram and links to system context.
- `flows.md` contains sequence diagrams for key workflows.
- `code.md` links to each service root.
- `home.mdx`, `roadmap.mdx`, `running.md`, and `project-history.md` are Docusaurus site pages.
- `c4/` contains the original C4 DSL and rendered image.

## When updating documentation
- Keep diagrams in `overview.md` and `flows.md` in sync with service behavior.
- If APIs change, update the relevant `openapi.yaml` and link any new endpoints.
- Prefer small, focused edits that keep the docs approachable for first-time users.
