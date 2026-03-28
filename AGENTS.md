# AGENTS.md

This repository follows a learning-path-first, multi-state architecture. Agents should use this file as the primary operating contract.

## Core Model

- Learning guides live in `docs/guide/**/*.md` and must include normalized front-matter.
- Runnable implementation states live in `states/<id>/`.
- Contracts and architecture specs live in `specs/contracts` and `specs/architecture`.
- Agent prompts live in `prompts/**`.
- Learning graph index lives at `docs/learning-paths/index.md`.

## Levels and State IDs

- Level 0: `00-monolith`
- Level 1: `01-basic-microservices`
- Level 2: `02-containerized`
- Level 3: `03-service-mesh`
- Level 4: `04-contract-driven`
- Level 5: `05-ai-first`

Level 3 includes a Solo demo landing zone: `states/03-service-mesh/solo-demo`.

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
  id: "00-monolith|01-basic-microservices|02-containerized|03-service-mesh|04-contract-driven|05-ai-first"
  diffFromPrev: true
tags: ["learning-path","traderx"]
estimatedTimeMins: 20
owner: "@finos/traderx-maintainers"
---
```

Schema: `docs/.schema/frontmatter.json`  
Validation script: `tools/validate-frontmatter.sh`

## Required Contents Per State

Each state should include:

- `README.md` with Objectives, Run, Verify, Teardown, and What changed vs previous level
- `scripts/verify.sh` (or `.ps1`) exiting non-zero on failure

Level 3 additionally requires:

- `states/03-service-mesh/solo-demo/manifests`
- `states/03-service-mesh/solo-demo/scripts`
- `states/03-service-mesh/solo-demo/observability`

## Prompt Pack

- `prompts/session/00_session-kickoff.md`
- `prompts/navigation/learning-path-navigator.md`
- `prompts/generation/state-from-contract.md`
- `prompts/explanation/diff-between-states.md`
- `prompts/validation/mesh-sanity-check.md`
- `prompts/contrib/new-learning-path.md`
- `prompts/explanation/release-notes-and-pr-plan.md` (optional)

Agents should prefer these prompts over ad-hoc improvisation.

## Quality Gates

```bash
tools/validate-frontmatter.sh
find states -maxdepth 3 -type f -name "verify.sh" -print -exec {} \;
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
