---
title: "March 31, 2026: State 009 - Replacing H2 with PostgreSQL"
slug: /blog/2026-03-31-state-009-postgres-architecture-track
---

# State 009: Replacing H2 with PostgreSQL

State `009-postgres-database-replacement` is the second architecture-track branch after state `007`.

This change keeps the same baseline functional behavior, APIs, and runtime entry model from state `003`, but replaces the underlying database runtime from H2 to PostgreSQL.

## Why This State

The project needed a more production-like SQL engine without adding heavy setup overhead. PostgreSQL gives us that while keeping local Docker Compose usage straightforward.

This also validates the SpecKit-first approach: we define a focused architecture delta, generate the state, run smoke checks, and publish a clean generated code branch.

## What Changed

- Added a PostgreSQL container runtime with deterministic init SQL.
- Updated `account-service`, `position-service`, and `trade-processor` to use PostgreSQL datasource/driver settings.
- Preserved baseline flow behavior (`F1` to `F4`) and existing REST/event contracts.
- Added state-specific runtime scripts and smoke tests for PostgreSQL readiness + baseline compatibility.

## Spec + Decision Links

- State spec pack: [/specs/postgres-database-replacement](/specs/postgres-database-replacement)
- ADR: [/docs/adr/006-state-009-use-postgres-for-database-replacement](/docs/adr/006-state-009-use-postgres-for-database-replacement)
- Learning guide: [/docs/learning/state-009-postgres-database-replacement](/docs/learning/state-009-postgres-database-replacement)
- Generated code branch: [code/generated-state-009-postgres-database-replacement](https://github.com/finos/traderX/tree/code/generated-state-009-postgres-database-replacement)

## Why This Matters For The Learning Graph

State `009` demonstrates that architecture substitutions can be done as isolated, reversible state transitions:

- branch from a stable parent state,
- apply one focused replacement axis,
- keep the rest of the system stable,
- publish as an independent generated branch for developers to inspect and run.
