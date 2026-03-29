# Position-Service Non-Functional Requirements

## Runtime

- NFR-POS-001: Default listen port shall be `18090` in baseline local mode.
- NFR-POS-002: Service startup should complete within 30 seconds on a warm local environment.
- NFR-POS-003: Service shall fail fast with clear logs if database connectivity is unavailable.

## Dependency Compatibility

- NFR-POS-004: Generated implementation must remain compatible with H2 TCP connection contract used in baseline state.
- NFR-POS-005: Runtime DB connection configuration shall remain env-configurable.

## API Reliability

- NFR-POS-006: `GET /trades/{accountId}` should complete within 250 ms p95 in local baseline mode.
- NFR-POS-007: `GET /positions/{accountId}` should complete within 250 ms p95 in local baseline mode.
- NFR-POS-008: Invalid requests and not-found paths shall return stable non-2xx responses.

## Compatibility

- NFR-POS-009: Endpoint paths and payload fields must remain backward compatible with current OpenAPI contract.
- NFR-POS-010: In pre-ingress local runtime, CORS must allow cross-origin browser access from other localhost ports.
