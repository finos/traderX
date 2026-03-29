# Trade-Service Non-Functional Requirements

## Runtime

- NFR-TS-001: Default listen port shall be `18092` in baseline local mode.
- NFR-TS-002: Service startup should complete within 20 seconds on a warm local environment.
- NFR-TS-003: Service shall fail fast with clear logs if reference-data, account-service, or trade-feed dependencies are unreachable.
- NFR-TS-004: In pre-ingress local runtime, service endpoints shall support cross-origin browser access.

## Performance And Reliability

- NFR-TS-005: Trade submission validation and publish handoff should complete within 500 ms p95 for local baseline workloads.
- NFR-TS-006: Publish failures to trade-feed shall be logged with request context.
- NFR-TS-007: Validation failure responses shall remain deterministic (`404`) for unknown account/ticker lookups.

## Compatibility

- NFR-TS-008: Compatibility with existing Angular UI request shape and endpoint path (`/trade/`) must be preserved.
- NFR-TS-009: Compatibility with trade-feed topic naming (`/trades`) and envelope publishing must be preserved.
- NFR-TS-010: Compatibility with downstream trade-processor payload expectations must be preserved.

## Observability

- NFR-TS-011: Logs shall capture trade submission attempts, validation outcomes, and publish actions.
- NFR-TS-012: Startup logs shall include bound HTTP port and dependency endpoint settings.
