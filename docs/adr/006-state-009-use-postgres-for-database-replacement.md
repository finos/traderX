---
title: ADR-006 Use PostgreSQL for State 009 Database Replacement
slug: /adr/006-state-009-use-postgres-for-database-replacement
status: accepted
date: 2026-03-31
decision-makers: Dov Katz, TraderX maintainers
consulted: Core contributors
informed: TraderX users and contributors
---

# Use PostgreSQL as the Database Engine in State 009

## Context and Problem Statement

State `003-containerized-compose-runtime` uses H2 as the runtime database. That choice kept local startup simple, but it limited realism for SQL behavior and migration paths. We need an architecture-track branch that swaps only the DB engine while preserving baseline functional behavior and simple local execution.

State scope: this ADR applies specifically to state `009-postgres-database-replacement` and descendants that inherit its database model.

## Decision Drivers

* Keep baseline behavioral compatibility for account, trade, and position flows.
* Improve realism of SQL runtime behavior in a local-friendly setup.
* Keep startup simple in Docker Compose.
* Keep migration incremental and traceable from state `003`.

## Considered Options

* Keep H2 runtime as-is.
* Replace H2 with PostgreSQL container.
* Replace H2 with MongoDB container.

## Decision Outcome

Chosen option: "Replace H2 with PostgreSQL container", because it improves database realism while preserving local simplicity and minimizing contract drift.

### Consequences

* Good, because SQL behavior is closer to common production patterns.
* Good, because official PostgreSQL container is straightforward for local Compose usage.
* Good, because this replacement is isolated to one architecture axis.
* Bad, because DB-dependent service configuration and sequence handling require migration changes.
* Bad, because H2 web-console diagnostics are no longer part of the runtime.

### Confirmation

Decision compliance is confirmed when:

* runtime uses PostgreSQL container with deterministic init SQL,
* DB-dependent services run against PostgreSQL and baseline flows pass,
* REST/event contracts remain baseline-compatible,
* generated state and docs are publishable as state `009`.

## Pros and Cons of the Options

### Keep H2 runtime as-is

* Good, because no migration effort is required.
* Good, because existing local behavior is already known.
* Bad, because SQL runtime realism remains limited.

### Replace H2 with PostgreSQL container

* Good, because PostgreSQL is widely used and production-like for SQL behavior.
* Good, because local Compose setup remains simple.
* Good, because migration can stay constrained to DB/runtime axis.
* Bad, because config and schema-init migration work is required.

### Replace H2 with MongoDB container

* Good, because operational setup can also be simple in containers.
* Bad, because current schema/query model is relational and SQL-oriented.
* Bad, because this would introduce a larger functional model change than desired for this step.

## More Information

Related state and artifacts:

* State pack: `/specs/postgres-database-replacement`
* Learning guide: `/docs/learning/state-009-postgres-database-replacement`
* Generated code branch: `code/generated-state-009-postgres-database-replacement`
