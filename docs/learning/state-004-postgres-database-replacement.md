---
title: "State 004: PostgreSQL Database Replacement"
---

# State 004 Learning Guide

## Position In Learning Graph

- Previous state(s): [003-containerized-compose-runtime](/docs/learning/state-003-containerized-compose-runtime)
- Dotted-line parent(s): none
- Next state(s): [005-messaging-nats-replacement](/docs/learning/state-005-messaging-nats-replacement)

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `canonical`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-004-postgres-database-replacement](https://github.com/finos/traderX/tree/code/generated-state-004-postgres-database-replacement)
- Authoring branch (spec source): [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)

## Code Comparison With Previous State

- Compare against `003-containerized-compose-runtime`: [code/generated-state-003-containerized-compose-runtime...code/generated-state-004-postgres-database-replacement](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-004-postgres-database-replacement)

## Plain-English Code Delta

- **Added:** PostgreSQL runtime initialization pack (`postgres-init/initialSchema.sql`) for deterministic baseline schema and seed data.
- **Added:** Postgres-specific smoke checks (readiness + baseline data presence).
- **Changed:** Runtime database engine changes from H2 server process to PostgreSQL container.
- **Changed:** Service datasource wiring for:
- **Changed:** `account-service`
- **Changed:** `position-service`
- **Changed:** `trade-processor`
- **Changed:** Account sequence ID generation query changes to PostgreSQL sequence syntax.

## Run This State

```bash
./scripts/start-state-004-postgres-database-replacement-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/postgres-database-replacement](/specs/postgres-database-replacement)
- Architecture: [/specs/postgres-database-replacement/system/architecture](/specs/postgres-database-replacement/system/architecture)
- Flows / topology: [/specs/postgres-database-replacement/system/runtime-topology](/specs/postgres-database-replacement/system/runtime-topology)
- Research: [link](/specs/postgres-database-replacement/research)
- Data model: [link](/specs/postgres-database-replacement/data-model)
- Quickstart: [link](/specs/postgres-database-replacement/quickstart)
- State ADR: [link](/docs/adr/006-state-004-use-postgres-for-database-replacement)
