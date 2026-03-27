# Web-Front-End (Angular) Non-Functional Requirements

## Runtime

- NFR-WEB-001: Default dev-server port shall be `18093` in baseline local mode.
- NFR-WEB-002: UI startup should complete within 30 seconds on a warm local environment.
- NFR-WEB-003: UI shall fail fast with clear logs if npm dependencies are missing.

## UX And Responsiveness

- NFR-WEB-004: Trade submit interactions should provide visible success/failure feedback within 1 second after server response.
- NFR-WEB-005: Blotter updates from trade-feed events should appear within 500 ms p95 in local baseline workloads.
- NFR-WEB-006: Core workflow shall remain usable on standard desktop viewport and common laptop viewport sizes.

## Compatibility

- NFR-WEB-007: Existing API path expectations and local port mappings for account/reference-data/trade-service/position-service/trade-feed must be preserved.
- NFR-WEB-008: Existing WebSocket topic subscription behavior must remain compatible with trade-feed and downstream services.
- NFR-WEB-009: Existing Angular route structure and module boundaries for trade components shall remain compatible.

## Observability

- NFR-WEB-010: Browser console logging for key trade workflow events should remain available in baseline mode.
- NFR-WEB-011: Build/runtime errors shall remain diagnosable from local npm output.
