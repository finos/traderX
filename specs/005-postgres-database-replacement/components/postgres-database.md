# Component: postgres-database

## Role

Persistent storage backend for account, position, and trade data in state `009`.

## Responsibilities

- host baseline schema and seed data for TraderX core data model,
- serve SQL queries from account-service, position-service, and trade-processor,
- provide readiness probes for deterministic startup ordering.

## Interfaces

- PostgreSQL TCP endpoint inside compose network: `database:5432`
- Host diagnostic endpoint: `localhost:18083`

## State Scope

- replaces H2 runtime component from state `003`,
- preserves baseline data model semantics and seed data intent.
