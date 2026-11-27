# Security outcomes, trading cost and alternative controls

Status: evaluation contract, not measured performance evidence. Implement the
cumulative baseline first; collect its timings before selecting optimizations.
This contract supports S019-07/08/10 and the later S019-14 platform comparison.

## Learning objective and presentation

For each demonstration, a security practitioner should be able to identify:

1. The protected asset, initiating identity and assumed attacker capability.
2. The layer that decides, what context it can see and what it cannot establish.
3. Independent business effects after asynchronous work finishes, including any
   residual permitted action. A rejection, alert or process exit alone is not
   proof that the business effect was prevented.
4. The measured performance and operating cost of that boundary.
5. An alternative implementation, any retained application responsibility and
   the remaining risk if the alternative is chosen.

The experiment view should pair the existing learning-progression diagram with
an actual request/execution path, active controls, decision evidence, final
SQL/message outcomes and a cost panel. Show `unmeasured`, `not applicable` or
`incomplete` explicitly; never turn absent measurements into zero overhead.

## Compare the relevant paths

Separate browser order submission, matching/service-token acquisition, durable
processor settlement, asynchronous notification, read snapshots and operator
lookup. Operator-path results must not be presented as latency evidence for the
execution path. Measure both request completion and time to committed settlement
or visible snapshot, since asynchronous work can move rather than remove cost.

Freeze the synthetic workload, offered arrival rate, account/order mix, dataset,
image digests, host shape, concurrency and control configuration. Include normal
load, bursts, reconnects, rotation, restart and controlled dependency failure.
Warm up explicitly; distinguish cold-start/handshake/token-refresh samples from
steady state. Replay the same workload in repeated, interleaved baseline and
candidate runs. Collect enough observations to support reported tail quantiles;
record sample counts, run duration, variation and measurement uncertainty. Avoid
coordinated omission by recording offered load and queued/dropped/time-out work,
not only successful-response latency.

Report p50/p95/p99 and variability, order/settlement throughput, errors/timeouts,
queue depth, CPU/memory, network/storage, alert delay and recovery time. Include
control-plane, proxies/agents, collectors and certificate/identity operations in
resource and effort totals. Do not extrapolate disposable shared-runner results
to production trading hardware or microsecond execution requirements.

Trading-owner latency/availability budgets and tolerances must be declared
before comparison. They are not yet specified for this lab; do not invent a
universal acceptable security overhead. A control being expensive is a result
to investigate, not automatic permission to remove a required protection.

## Alternatives and compensating-control decision record

For every proposed removal, relocation or replacement, record:

| Field | Required evidence |
| --- | --- |
| Threat and boundary | Original security objective, trust assumptions and passing tests |
| Candidate | Exact pinned configuration; application, gateway, mesh, host or datastore responsibility |
| Prevention/detection | Same negative scenario, independent effects, detection/containment delay and residual risk |
| Bypass and failure | Direct backend, identity/certificate failure, compromised service, policy outage, restart and rollback |
| Business correctness | Normal orders, cancellation, duplicate/replay handling and unrelated data unchanged |
| Performance | Matched-load per-path measurements, all errors/queues and confidence limits |
| Complexity | Code removed plus configuration/adapters added; setup, rotation, debugging and upgrade effort |
| Decision | Retain, replace, combine or defer; accountable owner and explicitly accepted risk |

A network restriction, workload identity or authenticated transport must not be
credited with account/business authorization unless the tested policy actually
receives and validates the necessary context. The within-grant, same-process
canary is especially important: an allowed service-to-database connection is not
by itself a distinction between an authorized and unauthorized business write.

Evaluate infrastructure isolation, gateway policy, service mesh, database-side
restrictions and runtime observation/enforcement as separate candidates where
relevant. Treat both security coverage and performance improvement as hypotheses.
A mesh may relocate implementation or introduce additional work; the scorecard
must measure the whole system and preserve the accepted baseline for comparison.
Detection plus response is not equivalent to prevention before impact; if chosen
as compensation, report the possible effect window and explicit risk acceptance.

## Delivery order and exit criteria

1. Complete runnable images and real dependencies, then accept one combined
   hardened deployment with independent evidence and reset.
2. Demonstrate outside-grant denial and within-grant residual authority under
   that baseline, with one runtime engine's observation/enforcement variants.
3. Capture baseline per-path performance and resource measurements as S019-10;
   keep performance collection passive until workload/budget assumptions are set.
4. Run the separately gated [platform comparison](platform-control-comparison.md)
   against identical security/correctness tests and matched workloads. Introduce
   CALM later as its own model-driven successor state.

Publish a reproducible comparison and decision record that explains what each
layer buys, its limits and measured cost. Do not advertise an optimized profile
or compensating control until its security, correctness and cost checks pass.
