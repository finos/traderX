# Account-Service Non-Functional Requirements

## Runtime

- NFR-AS-001: Default listen port shall be `18088` in baseline local mode.
- NFR-AS-002: Service startup should complete within 30 seconds on a warm local environment.
- NFR-AS-003: Service shall fail fast with clear logs if database connectivity is unavailable.

## Dependency Compatibility

- NFR-AS-004: Generated implementation must remain compatible with H2 TCP connection contract used in baseline state.
- NFR-AS-005: Generated implementation must remain compatible with people-service contract at `http://localhost:18089/People/GetPerson`.
- NFR-AS-006: Database credentials and host/port overrides shall remain env-configurable.

## API Reliability

- NFR-AS-007: `GET /account/{id}` should complete within 200 ms p95 in local baseline mode.
- NFR-AS-008: `GET /accountuser/` should complete within 250 ms p95 in local baseline mode.
- NFR-AS-009: Invalid or missing resources shall return stable non-2xx responses with useful error text.

## Compatibility

- NFR-AS-010: Endpoint paths and payload fields must remain backward compatible with current OpenAPI contract.
- NFR-AS-011: In pre-ingress local runtime, CORS must allow cross-origin browser access from other localhost ports.
