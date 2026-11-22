# Convergence Rationale (C2)

State `009-order-management-matcher` is the C2 functional convergence state.

Rationale:

- It brings core functional capabilities (pricing awareness and order lifecycle) onto the C1 architecture baseline.
- It is the primary compose-first "feature-complete" state for developers who do not need Kubernetes/Tilt.
- It keeps inherited observability demo-ready by documenting Grafana access in generated snapshots and using domain labels for pricing, messaging, runtime, and order dashboards instead of future-state tags.
- It is the preferred base for future functional extensions unless a state-specific learning objective says otherwise.

- Issue #465 upgrades the inherited Java baseline to public Spring Boot 4.0.8, Spring Framework 7.0.9, Data JPA 4.0.7, and Tomcat 11.0.26. Jackson 3 and Springdoc 3 compatibility changes preserve the existing HTTP and messaging contracts without adding security suppressions.
- Issue #481 adds market order support to the order management and matcher lifecycle. It introduces optional limit price validation for market orders, immediate STP execution against current market price at order ingestion, and updates order tickets, blotters, and admin views while preserving baseline limit order processing. PR #495 review updates align the PostgreSQL orderbook schema to nullable limit prices with an explicit ordertype check constraint, enable admin cancel and force-fill for partially filled orders with non-market safety guards, and ensure patch automation fails fast on unapplied patches.

## Learning evidence at this checkpoint

At C2, the learning contract combines inherited pricing and observability with the order lifecycle. A learning partner asks the learner to reconcile requested, filled and remaining quantities against executions and positions instead of treating a successful order request as a completed trade. The canonical `learning-contract.json` supplies objective mappings, diagnostic questions, graduated hints and assessment evidence for both human and agent-assisted study.

Issue #487 recovers the C2 demo without weakening deployment eligibility. State-local
runtime image rebuild recipes preserve application contracts and PostgreSQL major
version 16; maintained log collection retains the existing Compose/dashboard labels.
Any fixed-source scanner disposition requires review, exact image/package scope and
expiry. Recovery evidence and the subsequent shared-generator work are tracked in
`docs/operations/state-009-recovery.md`.

PR #495 publication retains the state-owned conformance pack and its regression
runner in generated snapshots. The pack carries the exact generated production
initialization SQL so the reference tests remain runnable in Kubernetes descendants
that remove Compose-only directories. This preserves the inherited NFR-01323
regression obligation without retaining obsolete runtime components.
