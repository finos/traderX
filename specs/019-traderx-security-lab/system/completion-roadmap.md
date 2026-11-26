# First-release completion assessment

Assessment date: 26 November 2026. This is a planning estimate, not acceptance
evidence or a delivery commitment. Checkpoints are tracked in [tasks](../tasks.md);
the [integrated contract](integrated-acceptance.md) defines completion.

The real trader/reader browser journey, three Python image builds and the
43-check packaged-worker TLS/recovery campaign and 41-check position-image
HTTPS/scoped-read/SQL-TLS campaign are accepted checkpoints. The remaining work is mainly packaging, cumulative control
integration and release validation. Passing components do not establish that
their combined deployment is secure or reproducible.

## Remaining work and estimate

| Work block | Completion evidence | Estimated focused effort |
| --- | --- | --- |
| Packaging and transport | Worker TLS delivery/replay/restart is accepted; remaining Java and .NET images consume private configuration and enforce identity, and support services are provisioned | 1–2 working days |
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
Next reuse the verified private Spring interface for account, matcher and processor
(S019-06a3b2), then package the separately reviewed .NET adapter (b3) and provision
support-service TLS/flows (b4). Copilot PR #521 supplies the .NET launcher only;
its nine source tests do not establish image or operator-directory acceptance. Keep local
Docker and Citrix untouched; continue with disposable hosted Linux execution
and small local source tests.
