# Reference-Data Non-Functional Requirements

## Runtime

- NFR-RD-001: Default listen port shall be `18085` in baseline local mode.
- NFR-RD-002: Service startup time should be under 15 seconds on a warm local environment.
- NFR-RD-003: Health endpoint `/health` shall be available immediately after startup.

## Performance

- NFR-RD-004: `GET /stocks` should complete within 300 ms p95 in local baseline.
- NFR-RD-005: `GET /stocks/{ticker}` should complete within 150 ms p95 in local baseline.

## Reliability

- NFR-RD-006: Service shall fail fast with clear startup error logs if required runtime/dependencies are missing.
- NFR-RD-007: Unhandled exceptions shall return stable JSON error responses and non-2xx HTTP codes.

## Observability

- NFR-RD-008: Startup logs shall include bound port and endpoint readiness signal.
- NFR-RD-009: Request logs shall include method, path, status code, and latency.

## Compatibility

- NFR-RD-010: API contract for `/stocks*` must remain compatible with existing `trade-service` and web frontend consumers.
- NFR-RD-011: In pre-ingress local runtime, CORS must allow cross-origin UI calls from other localhost ports.
- NFR-RD-012: Dataset coverage in generated mode must preserve baseline CSV symbol universe (no reduced demo-only symbol list).
