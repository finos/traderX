# State 019 implementation plan

1. Register the planned C3 child and review existing checkpoint evidence. Publish a draft portal preview and tracking issue.
2. Promote the profile into deterministic state generation/start/stop/test entrypoints; preserve pinned fixtures and earlier states.
3. Integrate identity into the trading UI and owning APIs, then cut over authenticated NATS with dynamic account subjects and browser credentials.
4. Integrate the TLS/WAF gateway, operator isolation, complete CNI policy graph, workload/SQL controls and signed-image admission. Re-run positive trading and negative checks together.
5. Implement the residual-authority canary, independent evidence and repeatable reset; select/pin and test one runtime observation/enforcement engine.
6. Finish staged learner UI, versioned CCC mapping, performance/resource checks and independent clean-machine/CI reproduction.
7. Publish only after acceptance review. CVE/OSERA is a separately gated optional exercise; supplier evaluation and the CALM successor remain separate workstreams.

See the [detailed plan](../012-platform-convergence-c3/security-lab/plan.md) and [release audit](../012-platform-convergence-c3/security-lab/state-readiness.md). Generation remains planned; registration must not expose a nonworking runtime command.

Offline generation checkpoint S019-03a is verified from a shallow clone; see [recorded evidence](evidence/2026-11-23-offline-checkpoint.json). The parent S019-03 task remains open until cumulative generation and runtime lifecycle entrypoints are integrated.
