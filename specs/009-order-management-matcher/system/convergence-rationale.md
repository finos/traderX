# Convergence Rationale (C2)

State `009-order-management-matcher` is the C2 functional convergence state.

Rationale:

- It brings core functional capabilities (pricing awareness and order lifecycle) onto the C1 architecture baseline.
- It is the primary compose-first "feature-complete" state for developers who do not need Kubernetes/Tilt.
- It keeps inherited observability demo-ready by documenting Grafana access in generated snapshots and using domain labels for pricing, messaging, runtime, and order dashboards instead of future-state tags.
- It is the preferred base for future functional extensions unless a state-specific learning objective says otherwise.

- Issue #465 upgrades the inherited Java baseline to public Spring Boot 4.0.8, Spring Framework 7.0.9, Data JPA 4.0.7, and Tomcat 11.0.26. Jackson 3 and Springdoc 3 compatibility changes preserve the existing HTTP and messaging contracts without adding security suppressions.
