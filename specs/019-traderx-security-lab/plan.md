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

S019-03c2 provides create-once private identity persistence and verified reuse through the bootstrap SQL adapter. Next integrate it with owned Kubernetes Secret/PVC initialization and guarded start/stop; full deployment remains blocked.

S019-03c3 adds the database-only Kubernetes ownership/start/stop adapter and verifies the shared SQL initialization/resume path through two live PostgreSQL restarts. Live Kubernetes adapter acceptance is S019-03c4; telemetry and application rollout plus normal trading remain part of S019-03c.

S019-03c4 and S019-03c5 are live-validated: immutable SQL Secrets/PVC provisioning, transactional failure recovery, two database Pod recreations, and a fifteen-Deployment trading candidate with independent settlement/cancellation outcomes and a workload-admission denial. Next integrate fresh telemetry storage and collector migration, then the cumulative state entrypoints and full acceptance suite.

S019-03c6/c7 complete the candidate runtime lifecycle: non-root telemetry initializers, isolated collector, retained logs/metrics/traces/dashboard after recreation, all nineteen Deployments ready together, and passing trading outcomes after telemetry restart. Citrix remained running and host pressure stayed normal in sampled observations. S019-03c is complete for the local candidate; S019-03 still requires cumulative generation/fresh-clone entrypoints and the remaining security/release gates are unchanged.

S019-03d adds a checkout-relative contributor entrypoint, complete local runtime dependency hashes, verified dispatch and recovery stop independent of artifacts. Fresh shallow-checkout artifact reproduction is the next validation; standalone generated-state packaging and clean-machine runtime acceptance remain open.
