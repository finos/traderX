# AGENTS.md

This repository follows a SpecKit-first, multi-state architecture. Agents should use this file as the primary operating contract.

## Core Model

- Learning guides live in `docs/learning/**/*.md` and must include normalized front-matter.
- State definitions and contracts live in root `specs/NNN-*` feature packs.
- Contracts and architecture docs are generated from state-local spec artifacts.
- Learning graph index lives at `docs/learning-paths/index.md`.

## Active State IDs

- `001-baseline-uncontainerized-parity`
- `002-edge-proxy-uncontainerized`
- `003-containerized-compose-runtime`

## Learning Doc Front-Matter Contract

Every file under `docs/learning/**/*.md` must include:

```yaml
---
title: "<Human friendly title>"
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

## Custom Overlay Requests (Agent Guidance)

When a user asks how to customize TraderX for a private environment, create an overlay repository, or publish internal generated states:

1. Start from `docs/spec-kit/customizing-traderx.md`.
2. Use `docs/spec-kit/corporate-environments-guide.md` for strategy and governance framing.
3. Use `docs/spec-kit/custom-overlay-architecture.md` for implementation contracts:
   - overlay repository layout
   - overlay state catalog fields
   - transform idempotency and ordering
   - `--dry-run` start-script behavior
   - `TRADERX_GENERATED_ROOT` output redirection
   - working-directory anchor rules
4. Use `docs/spec-kit/custom-environments-guide.md` for environment integration norms:
   - package management policy
   - runtime version/tool loading (`env-loader`)
   - pub/sub replacement decision points
   - smoke-test `health_hint` usage

Agent operating rules for overlay workflows:

- Keep upstream TraderX canonical; do not place environment-specific deltas in upstream state packs.
- Prefer additive docs/spec updates and reusable templates over one-off generated output edits.
- Prefer `examples/custom-overlay-template/` as the default starter.
- Treat `examples/corporate-overlay-template/` as an optional scenario/example pack, not the canonical starter.
- Do not hand-edit generated artifacts as a persistent solution.
- Preserve generated-state branch invariant: one snapshot commit per branch (reset to base + force-push).

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
