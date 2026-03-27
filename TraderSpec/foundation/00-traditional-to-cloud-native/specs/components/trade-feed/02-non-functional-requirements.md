# Trade-Feed Non-Functional Requirements

## Runtime

- NFR-TF-001: Default listen port shall be `18086` in baseline local mode.
- NFR-TF-002: Service startup should complete within 10 seconds on a warm local environment.
- NFR-TF-003: Service shall fail fast with clear logs if required Node runtime/dependencies are missing.

## Throughput And Latency

- NFR-TF-004: Publish-to-subscriber dispatch should complete within 150 ms p95 for local baseline workloads.
- NFR-TF-005: Subscribe/unsubscribe operations should complete within 100 ms p95 for local baseline workloads.

## Compatibility

- NFR-TF-006: Socket command compatibility must be preserved for current Angular and Java publishers/subscribers.
- NFR-TF-007: In pre-ingress local runtime, cross-origin browser websocket usage must remain allowed.
- NFR-TF-008: Wildcard inspector topic behavior (`/*`) must remain backward compatible.

## Observability

- NFR-TF-009: Logs shall capture subscribe/unsubscribe/publish activity with topic and sender details.
- NFR-TF-010: Startup logs shall include bound port information.
