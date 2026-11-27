# First-release completion assessment

Assessment date: 27 November 2026. This is a planning estimate, not acceptance
evidence or a delivery commitment. Checkpoints are tracked in [tasks](../tasks.md);
the [integrated contract](integrated-acceptance.md) defines completion.

The real trader/reader browser journey, three Python image builds and the
43-check packaged-worker TLS/recovery campaign and 41-check position-image
HTTPS/scoped-read/SQL-TLS campaign are accepted checkpoints. Account (44 checks),
processor (51), matcher (46) and people-service (43) actual-image campaigns are
now accepted too. The remaining work is mainly support-service composition,
supported-runtime migration, cumulative controls and release validation. Passing components do not establish that
their combined deployment is secure or reproducible.

## Remaining work and estimate

| Work block | Completion evidence | Estimated focused effort |
| --- | --- | --- |
| Packaging and transport | Core Java/.NET image interfaces and worker TLS/recovery are accepted; provision real support services and migrate the inherited .NET runtime before release | 1–2 working days |
| Cumulative hardened deployment | One deployment passes real trading, broader identity/recovery cases, gateway/WAF, CNI, scoped SQL/broker and trusted-image boundaries; external evidence survives restart | 2–4 working days |
| Residual misuse and runtime comparison | Outside-grant denial and within-grant canary effects, one runtime engine in observation/enforcement modes, independent outcomes and two resets | 1–2 working days |
| Learner and release validation | Guided experiments/assessments, control/evidence mapping, resource/performance measurements, unattended fresh-clone reproduction and contributor walkthrough | 1–2 working days |

The planning range is **5–10 focused working days** for a publishable first
release, assuming hosted compute remains available and implementation/review can
overlap. This is effort, not unattended elapsed time. Reassess after cumulative
deployment: certificate/configuration interfaces, network restrictions and
recovery can reveal integration work that separate campaigns cannot predict.
CI retries, provider availability and independent contributor feedback can extend
the calendar time. Count observed acceptance gates, not unchecked parent-task
totals or a speculative completion percentage.

## Scope of “complete”

The first release includes a usable staged experiment portal, normal authorized
trading under the integrated controls, residual-authority demonstrations,
one runtime observation/enforcement comparison, recoverable synthetic data,
sanitized evidence and a reproducible learning guide. Preparing release artifacts
does not authorize merging Main or publishing a generated state.

The optional CVE/upstream-fix/OSERA exercise, supplier-product evaluation,
ingress/service-mesh comparison and CALM successor are separate follow-on work.
Their planned documentation may ship with explicit availability labels; they
must not be advertised as implemented experiments until their own gates pass.

## Immediate next gate

S019-06a3c is accepted in the [packaged-worker evidence](../evidence/2026-11-26-worker-image-delivery.json).
S019-06a3b1 now has [41 passing image checks](../evidence/2026-11-26-position-image.json).
Account (b2a) and processor (b2b) now have 44 and 51 passing actual-image checks
respectively; see [account evidence](../evidence/2026-11-27-account-image.json) and
[processor evidence](../evidence/2026-11-27-processor-image.json). Matcher (b2c) now
has [46 passing actual-image checks](../evidence/2026-11-27-matcher-image.json),
closing b2. The latest [full twelve-job regression](https://github.com/finos/traderX/actions/runs/45953040241)
and 490 source tests pass at `8f1b6fe9`, including a second fresh people-image build.

The [people image checkpoint](../evidence/2026-11-27-people-image.json) closes b3
with 43 checks at `8f1b6fe9`: native culture operations, actual private launcher,
verified HTTPS, all three operator routes, user/claim denials, trust expiry and
restart. The inherited .NET 9 profile still requires a supported-runtime migration
and identical regression before release (b3r).

Next complete real support-service TLS/flows (b4):

1. Compile exact support-workload admission and required network flows; the
   current application-only policy cannot admit support pods. Verify Kubernetes
   private-volume/fsGroup behavior rather than inferring it from Docker fixtures.
2. Replace the matcher's synthetic OAuth peer with real Keycloak against accepted
   matcher/processor images; prove scoped settlement, denials and recovery.
3. Package the actual Node reference-data/price-publisher with verified HTTPS and
   scoped broker publishing, then prove actual snapshots and price ticks.
4. Activate and validate one cumulative deployment and browser journey.

The [security-cost evaluation contract](security-cost-evaluation.md) and learning
objective require independent effects, per-path measurements and matched tests
before crediting an alternative control. Cost measurements remain uncollected;
mesh gains remain hypotheses. Keep local Docker and Citrix untouched and use
hosted Linux for heavy execution.
