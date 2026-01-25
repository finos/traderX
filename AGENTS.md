# AGENTS.md

This repository is the FINOS TraderX sample trading application. It is intentionally simple, non-production, and designed for local experimentation across a distributed set of services.

## Start here (project context)
- `README.md` for overall purpose, run modes, and default ports.
- `docs/README.md`, `docs/overview.md`, and `docs/flows.md` for architecture and sequence flows.
- `docs/c4/workspace.dsl` for the C4 diagram source (use Structurizr Lite to render).

## Repository map (service roots)
- `database/` (H2 database)
- `reference-data/` (Node/NestJS reference data)
- `trade-feed/` (Node/Socket.IO pub-sub)
- `people-service/` (.NET)
- `account-service/` (Java/Spring Boot)
- `position-service/` (Java/Spring Boot)
- `trade-service/` (Java/Spring Boot)
- `trade-processor/` (Java/Spring Boot)
- `web-front-end/` (Angular + React clients)
- `docs/` and `website/` (documentation site)
- `gitops/` and `ingress/` (K8s/Tilt and ingress config)

## Quick run options
- Docker Compose (full system): from repo root, `docker compose up` (see `README.md`).
- Kubernetes/Tilt: see `gitops/local/Tiltfile` and `README.md` for `tilt up`.
- Manual run: see `README.md` for the recommended startup sequence and port env vars.

## Service-level guidance
- Each service has a `README.md` with run details and prerequisites. Read that before editing.
- OpenAPI specs live in `*/openapi.yaml` and Swagger UI is typically exposed at `/swagger-ui.html` when running.
- Java services use Gradle wrapper (`./gradlew`) from their service directory.
- Node services use their local `package.json` scripts.
- `web-front-end/` contains both Angular and React implementations; check each subfolder's README.

## When making changes
- Prefer small, targeted edits in the service you are touching; do not refactor cross-service behavior unless requested.
- If behavior or APIs change, update the corresponding `openapi.yaml` and any relevant docs in `docs/`.
- Keep the non-production, demo nature of the project in mind.

## Keeping diagrams in sync
When adding, removing, or changing services or their interactions, update **all** relevant diagrams:

1. **C4 diagram** (`docs/c4/workspace.dsl`) - The Structurizr DSL is the source of truth for architecture. PNG images are auto-rendered by GitHub Actions on push.
2. **Mermaid diagrams** in `docs/overview.md` (simplified architecture) and `docs/flows.md` (sequence diagrams).
3. **Component table** in `README.md` if adding/removing services.

The C4 DSL and Mermaid diagrams should stay consistent—if you update one, check if the other needs the same change.

## Documentation and website
The project has two content surfaces that may overlap:
1. **`docs/`** - Markdown files served by Docusaurus (architecture, flows, running instructions)
2. **`website/src/components/`** - React components for the landing page (feature highlights, intro text)

**Avoid duplication**: The landing page is marketing-style (logo, tagline, feature cards, CTAs). The `docs/` folder is the reference material. If you add content, decide which surface it belongs to—don't put the same text in both places.

**Project history**: When making **major changes** (new services, architectural shifts, significant features), add an entry to `docs/project-history.md`. Minor fixes and routine maintenance do not need to be recorded.

**Relative links in docs**: Links like `../account-service` work on GitHub. The Docusaurus remark plugin (`website/src/remark/transformRelativeLinks.js`) converts them to full GitHub URLs at build time. Keep using relative links in `docs/` markdown files.

## Useful files by task
- Architecture/flows: `docs/overview.md`, `docs/flows.md`, `docs/c4/workspace.dsl`
- Local run and ports: `README.md`
- Docker/K8s: `docker-compose.yml`, `gitops/local/Tiltfile`
- Front-end: `web-front-end/angular/README.md`, `web-front-end/react/README.md`
- Docs site: `website/README.md`, `docs/`
