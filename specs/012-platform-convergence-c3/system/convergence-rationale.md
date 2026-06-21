# Convergence Rationale (C3)

State `012-platform-convergence-c3` is the C3 platform convergence state.

Rationale:

- It marks the canonical platform handoff after the Kubernetes + Tilt progression.
- It includes dotted-line lineage from C2 to show functional readiness feeding the platform milestone without introducing multi-parent publish ancestry.
- It is the recommended jumping-off point for Kubernetes-native enhancements.
- It inherits the hardened Kubernetes readiness preflight so C3 published-image, smoke-test, and scanner workflows wait for both rollout status and ingress-level service readiness.
