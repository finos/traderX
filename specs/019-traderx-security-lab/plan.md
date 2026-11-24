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

Composition preserves an explicit deployment blocker: the historical storage overlays require restore/initialization and SQL grants, so they cannot serve as fresh-cluster bootstrap. Finish S019-03c before exposing a generated start command; offline composition is S019-03b, not cumulative runtime acceptance.

S019-03b composition evidence is recorded in [the control-bundle result](evidence/2026-11-23-control-composition.json). All nineteen application deployments and the infrastructure collector are represented; the generated plan explicitly blocks deployment pending S019-03c.

Fresh database initialization is isolated as S019-03c1: a transactional schema/seed/grant compiler and bounded database campaign. The parent lifecycle task requires persistent credentials, Kubernetes bootstrap/restore and application rollout before deployment can be enabled.

The [24 November database campaign](evidence/2026-11-24-fresh-database-bootstrap.json) records two successful fresh initializations, exact service-grant checks, transactional failure recovery and preserved data/credentials on refusal. This completes S019-03c1, not full cluster lifecycle acceptance.
