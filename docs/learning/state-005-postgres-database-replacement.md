---
title: "State 005: PostgreSQL Database Replacement"
pagination_prev: null
pagination_next: null
---

# State 005 Learning Guide

<!-- Generated from specs/005-postgres-database-replacement/learning-contract.json; edit the source. -->

## Replace persistence without changing the business contract

Changing databases tests how much of an application’s behavior depends on its storage engine. For developers exploring persistence, replace H2 with PostgreSQL and use a trade record to investigate the boundary between application lifetime and stored data.

[How to learn with TraderX states](/docs/learning/how-to-learn)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

Compose packages the application with H2 persistence.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 004-containerized-compose-runtime

[Predecessor guide](/docs/learning/state-004-containerized-compose-runtime)

- **Carry forward:** Run the application as Compose services behind NGINX and distinguish process startup from readiness.
- **Why move:** Compose packages the application with H2 persistence.
- **Add or revise:** Move persistence to PostgreSQL while retaining account, trade and position behavior.
- **Evidence to collect:** The connection targets PostgreSQL and the trade survives an application restart. Business contract parity must be observed, not assumed from successful connectivity. An application restart leaves database storage intact. Volume deletion has a different durability boundary and is not a routine parity check.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| Compose packages the application with H2 persistence. | Move persistence to PostgreSQL while retaining account, trade and position behavior. |

### Concepts before tools

- A database dialect defines SQL behavior; a JDBC driver connects Java to it. Persistence across an application restart is different from retention after deleting a database volume.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Identify the PostgreSQL connection boundary and demonstrate that a trade survives an application-only restart.
- **interpret-evidence:** Explain the evidence boundary: An application restart leaves database storage intact. Volume deletion has a different durability boundary and is not a routine parity check.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Start this state and run its smoke test. Inspect the generated database service and application connection configuration. Book a small trade, record its identifier, restart only the application service, and retrieve the trade again.

**Expected observation and meaning:** The connection targets PostgreSQL and the trade survives an application restart. Business contract parity must be observed, not assumed from successful connectivity.

Supporting material: [quickstart](/specs/postgres-database-replacement/quickstart) · [architecture](/specs/postgres-database-replacement/system/architecture) · [runtime-topology](/specs/postgres-database-replacement/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

Inspect the Compose volume configuration and stop procedure before shutting down. Explain what would happen if the database volume were explicitly removed; do not delete a volume containing valued data.

**Expected observation and meaning:** An application restart leaves database storage intact. Volume deletion has a different durability boundary and is not a routine parity check.

Supporting material: [spec](/specs/postgres-database-replacement/spec) · [contract-delta](/specs/postgres-database-replacement/contracts/contract-delta).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** What did your restart prove, and what did it leave untested?

**Assessment guidance:** It demonstrated persistence outside the application process. It did not demonstrate backup recovery, production availability or safe destructive volume removal.

### Scope and limitations

- An application restart leaves database storage intact. Volume deletion has a different durability boundary and is not a routine parity check.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [004-containerized-compose-runtime](/docs/learning/state-004-containerized-compose-runtime)
- Dotted-line parent(s): none
- Next state(s): [006-messaging-nats-replacement](/docs/learning/state-006-messaging-nats-replacement)

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `canonical`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-005-postgres-database-replacement](https://github.com/finos/traderX/tree/code/generated-state-005-postgres-database-replacement)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `004-containerized-compose-runtime`: [code/generated-state-004-containerized-compose-runtime...code/generated-state-005-postgres-database-replacement](https://github.com/finos/traderX/compare/code%2Fgenerated-state-004-containerized-compose-runtime...code%2Fgenerated-state-005-postgres-database-replacement)

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
./scripts/start-state-005-postgres-database-replacement-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/postgres-database-replacement](/specs/postgres-database-replacement)
- Architecture: [/specs/postgres-database-replacement/system/architecture](/specs/postgres-database-replacement/system/architecture)
- Flows / topology: [/specs/postgres-database-replacement/system/runtime-topology](/specs/postgres-database-replacement/system/runtime-topology)
- Research: [link](/specs/postgres-database-replacement/research)
- Data model: [link](/specs/postgres-database-replacement/data-model)
- Quickstart: [link](/specs/postgres-database-replacement/quickstart)
- State ADR: [link](/docs/adr/006-state-005-use-postgres-for-database-replacement)
