# Trade-Processor Non-Functional Requirements

## Runtime

- NFR-TP-001: Default listen port shall be `18091` in baseline local mode.
- NFR-TP-002: Service startup should complete within 20 seconds on a warm local environment.
- NFR-TP-003: Service shall fail fast with clear logs when database or trade-feed dependencies are unreachable.
- NFR-TP-004: In pre-ingress local runtime, service endpoints shall support cross-origin browser access.

## Consistency And Throughput

- NFR-TP-005: Trade-to-position persistence shall be atomic within a single processing transaction.
- NFR-TP-006: Processing latency for a single inbound order should complete within 700 ms p95 on local baseline workloads.
- NFR-TP-007: Message publication for resulting account updates should occur in the same processing cycle after persistence.

## Compatibility

- NFR-TP-008: Compatibility with trade-service published `TradeOrder` payload shape must be preserved.
- NFR-TP-009: Compatibility with position-service reads from `TRADES` and `POSITIONS` tables must be preserved.
- NFR-TP-010: Outbound topic naming and payload shape for account updates must remain unchanged.

## Observability

- NFR-TP-011: Logs shall capture inbound order receipt and processing completion/failure.
- NFR-TP-012: Startup logs shall include successful socket connection/subscription and bound HTTP port.
