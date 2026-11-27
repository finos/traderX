# State 019 implementation plan

State 019 is the planned, optional security-learning child of C3. It is not yet
an accepted combined deployment or a published generated state. The
[integrated acceptance contract](system/integrated-acceptance.md) defines the two
current phases: authenticated application behavior, then the same behavior under
enforced deployment controls. Component success does not close either phase.

Use [tasks](tasks.md) for task status, the [completion assessment](system/completion-roadmap.md)
for remaining release gates and dated effort estimates, and the
[phase checkpoint](evidence/2026-11-26-phase-one-two.json) for historical observations. Preserve the [C3 profile ledger](../012-platform-convergence-c3/security-lab/tasks.md)
and [release audit](../012-platform-convergence-c3/security-lab/state-readiness.md);
this plan records current dependencies rather than replaying their chronology.

## Accepted checkpoints and their limits

| Checkpoint | Recorded result | Remaining boundary |
| --- | --- | --- |
| Retained C3 lifecycle | [Nineteen deployments, telemetry persistence and trading](evidence/2026-11-24-consolidated-runtime.json) | Recovered local candidate, not unattended fresh-clone acceptance or the new authenticated core |
| Actual Angular journey | [24 browser and 13 independent effects/delivery checks](evidence/2026-11-26-browser-journey.json) | Broader same-campaign operator, expiry and interruption cases remain |
| Python role images | [Three OCI builds and 16 startup/configuration checks](evidence/2026-11-26-python-runtime-images.json) | Browser HTTPS/assets and private startup; no learner-facing gateway claim |
| Packaged workers | [43 TLS, rejection, replay and recovery checks](evidence/2026-11-26-worker-image-delivery.json) | Real worker effects in owned fixtures, not cumulative deployment |
| Java core images | [Position: 41](evidence/2026-11-26-position-image.json), [account: 44](evidence/2026-11-27-account-image.json), [processor: 51](evidence/2026-11-27-processor-image.json), [matcher: 46](evidence/2026-11-27-matcher-image.json) checks | Matcher OAuth peer is synthetic; real support-service provisioning remains |
| People image | [43 focused hosted checks at `8f1b6fe9`](https://github.com/finos/traderX/actions/runs/45952663140) | Actual OCI, native culture, HTTPS, operator and restricted-runtime proof; supported-runtime migration and combined deployment remain |
| Deployment compiler/admission | [30 real Kubernetes schema/admission checks](evidence/2026-11-26-phase-one-two.json) | Synthetic OCI descriptors and unscheduled probes do not prove application rollout, CNI enforcement or provenance |

Reviewed Copilot proposals #521/#522 are incorporated with independent fixes and
hosted acceptance. The [people packaging contract](system/people-image-packaging.md)
records the private .NET interface and native composition. Its inherited .NET 9
compatibility result is not a supported-runtime claim. The
[twelve-job regression](https://github.com/finos/traderX/actions/runs/45953040241)
is still in progress at this plan checkpoint; its overall result is not claimed.

## Next: real dependencies and support composition

Complete S019-06a3b4 before activating the eight-role authenticated application
core. Keep the retained C3 candidate available until replacement acceptance;
the core intentionally uses limit orders and disables legacy immediate booking.

1. **S019-06a3b4a — exact support inventory:** extend the
   [composition contract](system/integrated-deployment.md) with pinned support
   workloads, private configuration and admission rules. Permit only required
   gateway-to-identity and price-publisher-to-broker flows. The current
   application-only admission policy intentionally cannot activate support pods.
2. **S019-06a3b4b — real service identity:** replace the matcher fixture's synthetic
   OAuth peer with provisioned Keycloak and the accepted matcher/processor images.
   Prove correct client/audience settlement, no-effect wrong-secret/audience
   rejection and preserved execution identity during recovery.
3. **S019-06a3b4c — real market data:** package the Node reference-data and
   price-publisher services with private HTTPS and publish-only `pricing.*`
   authority. Keep snapshot/event quote state consistent, reject unsupported
   symbols, and verify BFF reads plus an actual publisher-to-matcher tick.
4. **S019-06a3b3r — supported .NET:** migrate the inherited people runtime before
   release, rerunning native, HTTPS/operator and combined acceptance unchanged.

## Then: accept the combined state

- Integrate deterministic fresh bootstrap, durable execution migrations, private
  credentials, verified TLS, broker permissions and owned lifecycle entrypoints.
  Historical storage overlays require initialization/grants; applying them alone
  is not fresh-cluster bootstrap. Preserve credentials/data on guarded reuse.
- Run one actual Angular/Keycloak/API/matcher/processor/worker journey with
  trader, reader and operator boundaries; cancellation, logout/expiry, reconnect
  and restart must retain independently checked SQL and downstream outcomes.
- Repeat that journey with TLS/WAF gateway routing, operator isolation, enforced
  CNI ingress/egress, restricted workloads, scoped SQL/broker authority and
  approved-image admission. Verify bypass denials and disabled/detect/block WAF
  modes without changing unrelated controls. Keep signatures/provenance and
  runtime trust distinct from OCI digest verification.
- Preserve authoritative evidence outside workloads, verify telemetry after
  recreation, and complete unattended fresh creation and fresh-clone
  generation/start/stop/test. Only then close parent S019-03/04/05/06 gates.

## Finish the learning release

After the combined baseline passes, implement S019-07/08: an outside-grant
counterpart and a bounded same-process, within-grant residual-authority canary.
Pin one runtime engine and compare observation, containment and prevention using
final effects after asynchronous work settles; an alert or killed process is not
proof of prevention. Demonstrate two independent resets and continued trading.

Finish S019-09/10/11/13 with staged experiment selection, trustworthy control
status, sanitized downloadable evidence, recovery and assessments. Extend the
[release-pinned CCC map](system/ccc-assessment-map.md) with measured evidence and
limitations; run independent contributor and clean-machine reproduction before
release review. The [learning contract](learning-contract.json) includes measured
security cost: follow [security-cost evaluation](system/security-cost-evaluation.md)
for matched-load per-path p95/p99, throughput, queues/errors, resource use and
operating effort. Budgets are unspecified and costs unmeasured; do not invent
acceptable overhead or claim an optimization from fewer code lines.

The optional CVE/upstream-fix/OSERA/VEX exercise, supplier-product evaluation and
[ingress/service-mesh comparison](system/platform-control-comparison.md) are
separately gated follow-ons. Test alternatives against identical security and
business-correctness outcomes, documenting compensating controls and residual
risk. Mesh savings are hypotheses. CALM belongs to a separate successor state;
none of these follow-ons is required to finish the manual baseline release.

## Execution constraints

Use isolated agent worktrees for independent source/contracts/tests; integrate
with review and signed-off commits. Run heavy builds and real acceptance on
owned disposable hosted runners. Keep generation sequential within each
workspace, and serialize full-cluster acceptance. Do not download/build images
or dependencies locally, share the screen, or interrupt Citrix. Preserve Docker
resource limits and capacity guards; do not solve failures by silently raising
limits or weakening controls. Update the tracking issue/PR and evidence after
observed results. Nothing merges to Main or publishes a generated state without
separate authorization.
