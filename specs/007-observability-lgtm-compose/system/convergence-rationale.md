# Convergence Rationale (C1)

State `007-observability-lgtm-compose` is the C1 architecture convergence state.

Rationale:

- It consolidates architecture hardening before functional expansion: durable data, robust messaging, and observability.
- It creates a stable operational baseline for adding functional features without re-solving platform instrumentation.
- It defines the demo-safe Grafana access convention: anonymous Viewer dashboards through ingress, state-scoped local admin credentials, and deterministic log collection defaults.
- It is the recommended branching point for new functional states unless a narrower pedagogical target is explicitly required.

- Issue #465 aligns inherited Java build context with Boot 4.0.8, Jackson 3.1.5, Springdoc 3.0.3, and Tomcat 11.0.26 so the observability overlay preserves the patched dependency baseline.
