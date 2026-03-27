# Database Non-Functional Requirements

## Runtime

- NFR-DB-001: Default ports shall be `18082` (TCP), `18083` (PG), `18084` (web console).
- NFR-DB-002: Service should reach TCP readiness within 30 seconds in local baseline mode.
- NFR-DB-003: Startup shall fail fast with clear logs if schema initialization fails.

## Reliability

- NFR-DB-004: Schema initialization shall be deterministic and repeatable per startup.
- NFR-DB-005: Baseline services depending on DB shall connect using `DATABASE_TCP_HOST=localhost`.

## Compatibility

- NFR-DB-006: Generated database behavior must remain compatible with existing Java/.NET service JDBC usage patterns in baseline.
- NFR-DB-007: Table definitions and seed data must preserve baseline query expectations for account/position/trade endpoints.
