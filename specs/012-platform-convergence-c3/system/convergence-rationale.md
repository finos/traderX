# Convergence Rationale (C3)

State `012-platform-convergence-c3` is the C3 platform convergence state.

Rationale:

- It marks the canonical platform handoff after the Kubernetes + Tilt progression.
- It includes dotted-line lineage from C2 to show functional readiness feeding the platform milestone without introducing multi-parent publish ancestry.
- It is the recommended jumping-off point for Kubernetes-native enhancements.
- It inherits the hardened Kubernetes readiness preflight so C3 published-image, smoke-test, and scanner workflows wait for both rollout status and ingress-level service readiness.

## Learning evidence at this checkpoint

At C3, the learning contract requires functional and platform evidence from one snapshot. A learning partner checks the 011 predecessor route, the C2 capabilities retained through 010 and 011, and the source of the running images. The dotted C2 relationship supplies context rather than a second generation parent. The canonical `learning-contract.json` supplies objective mappings, diagnostic questions, graduated hints and assessment evidence for both human and agent-assisted study.
