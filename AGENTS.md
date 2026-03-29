# AGENTS.md

This repository follows a SpecKit-first, multi-state architecture. Agents should use this file as the primary operating contract.

## Core Model

- Learning guides live in `docs/guide/**/*.md` and must include normalized front-matter.
- State definitions and contracts live in root `specs/NNN-*` feature packs.
- Contracts and architecture docs are generated from state-local spec artifacts.
- Learning graph index lives at `docs/learning-paths/index.md`.

## Active State IDs

- `001-baseline-uncontainerized-parity`
- `002-edge-proxy-uncontainerized`
- `003-containerized-compose-runtime`

## Guide Front-Matter Contract

Every file under `docs/guide/**/*.md` must include:

```yaml
---
id: learn-<slug>
title: "<Human friendly title>"
level: 0|1|2|3|4|5
prereqs:
  - learn-<slug-a>
outcomes:
  - "A concrete testable outcome"
state:
  id: "001-baseline-uncontainerized-parity|002-edge-proxy-uncontainerized|003-containerized-compose-runtime"
  diffFromPrev: true
tags: ["learning-path","traderx"]
estimatedTimeMins: 20
owner: "@finos/traderx-maintainers"
---
```

Schema: `docs/.schema/frontmatter.json`  
Validation script: `tools/validate-frontmatter.sh`

## Required Contents Per State

Each state feature pack should include:

- `spec.md` with FR/NFR and scenarios
- `plan.md` and `tasks.md` for execution
- `system/**` with requirements, flows, architecture model, and generated architecture docs
- `README.md` with state intent and scope

## Prompt Pack Status

Legacy `prompts/**` scaffolding has been retired from the active repository surface.
Use the canonical SpecKit artifacts and docs under `docs/spec-kit/**` instead.

## Quality Gates

```bash
tools/validate-frontmatter.sh
bash pipeline/speckit/validate-root-spec-kit-gates.sh
bash pipeline/speckit/validate-speckit-readiness.sh
bash pipeline/verify-spec-coverage.sh
```

If docs dependencies are installed:

```bash
cd website
npm run build
```

## Non-Breaking Policy

- Preserve earlier levels while evolving Level 4/5.
- Favor additive changes and clear migration notes.
- Never commit secrets or sensitive data.

## Active Technologies
- Java 21 (Spring Boot services), TypeScript/Node.js (Nest + Socket.IO + Angular), C# (.NET 9), SQL (H2) + Spring Boot, Gradle, NestJS, Socket.IO, ASP.NET Core, Angular, H2 (001-baseline-uncontainerized-parity)
- H2 over TCP/PG/Web ports (001-baseline-uncontainerized-parity)

## Recent Changes
- 001-baseline-uncontainerized-parity: Added Java 21 (Spring Boot services), TypeScript/Node.js (Nest + Socket.IO + Angular), C# (.NET 9), SQL (H2) + Spring Boot, Gradle, NestJS, Socket.IO, ASP.NET Core, Angular, H2
