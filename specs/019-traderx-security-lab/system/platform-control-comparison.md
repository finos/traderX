# Follow-on platform control comparison

Status: planned after the explicit State 019 baseline is accepted. No mesh,
ingress product or permanent successor state number is selected here.

## Learning objective

Rebuild the same tested security boundaries using shared platform capabilities,
then measure how much application code, duplicated configuration and operating
work can be removed without weakening the outcomes. Keep this comparison
separate from the CALM successor: platform enforcement and model-driven
configuration are two different experiments, which can be combined later.

Compare these profiles sequentially on the same synthetic workload:

1. Accepted State 019 baseline with explicit controls.
2. A selected ingress/gateway integration for external entry-point controls.
3. A selected service-mesh integration for workload-to-workload controls.
4. A combined profile only if it demonstrates a useful additional boundary.

Candidate responsibilities to evaluate include TLS and certificate rotation,
service identity, authenticated transport, route/destination policy, rate limits,
request telemetry and policy rollout. Treat support and actual enforcement as
questions to verify against pinned implementations, not assumed product features.
Keep business/account authorization, NATS subject permissions, database grants,
execution deduplication and transactional consistency visible in the comparison;
record which remain in the application or datastore and why.

## Common acceptance and effort scorecard

Run the same positive trading and negative tests. Include direct-backend bypass,
forged/untrusted identity, certificate/token expiry, policy changes, cancellation,
concurrent duplicate execution, restart, and the within-grant residual-authority
scenario. Record what each layer observes and the final database/message effects.
Do not credit transport authentication with proving business authorization.

For each control record:

- Baseline implementation and its passing evidence.
- Platform replacement, pinned versions, prerequisites and verified limitation.
- Application code removed; new policy/configuration and custom adapters added.
- Setup, certificate/identity rotation, troubleshooting and upgrade effort.
- CPU, memory, storage and latency costs, including control-plane requirements.
- Bypass tests, failure behavior and rollback/recovery results.

Use measured total effort, not just application line count. Run only one full
profile at a time on the local machine. Keep an unchanged accepted baseline as
the comparison point; do not rewrite State 019's history to imply it always used
the replacement platform.

## Exit criteria

Publish an evidence-backed recommendation: controls replaced, controls retained,
operational/resource tradeoffs and reproducible steps. Decide whether it merits a
separate TraderX successor state after the compatibility exercise. Then evaluate
how CALM could describe and generate those same controls, preserving the already
planned standalone CALM comparison.
