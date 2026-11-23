# Promotion to a TraderX security learning state

Decision: this work is intended to become a first-class TraderX state derived from
State 012/C3, not a separate side project. Its present location beneath C3 is an
experimental implementation profile, not an already registered/published state.
Keep reference C3 unchanged when promoting it. CALM is a separate successor state
that reproduces the same verified controls and compares manual versus model-derived
configuration. Radius and FDC3 are not prerequisites for the security state.

No state number is allocated here. The root catalog and specification namespace
must be checked when registering the feature; `specs/015-docs-portal-homepage` already
exists even though it is a portal pack rather than a runtime state. Do not assume
that the next runtime catalog number is automatically free.

## Readiness audit — 23 November 2026

| Release gate | Evidence already available | Work required before claiming acceptance |
| --- | --- | --- |
| First-class state definition | Security FR/NFR, threat assumptions, learning objectives, contracts, tasks and progression exist in the C3 profile | Allocate ID; create root feature pack with spec/plan/tasks/README, system requirements/flows/model/generated architecture and learning contract; register C3 parent in catalog and learning graph |
| Deterministic generation | Canonical overlays, pinned C3 snapshot/source/images, account candidate renderer and selected runtime renderers | Connect a cumulative state generator and start/stop/test scripts; remove dependence on this checkout/private runtime; regenerate twice from a fresh clone and compare outputs |
| Identity and business authorization | Real OIDC/PKCE, account/member filtering, write denials, key replacement, local sessions and Chrome reader/trader switch/logout pass | Integrate into actual Angular/trading flow and every owning API; validate user context, order submission/cancellation, operator routes and direct backend access; keep normal trading working |
| Broker security | Isolated TCP/WebSocket ACLs and client TLS/credential/reconnect tests; candidate C3 compatibility smoke | Finish dynamic account subject map and browser credential issuer; authenticated live broker cutover; expiry/revocation/reconnect and normal asynchronous settlement |
| Gateway, segmentation and image trust | Isolated WAF three-mode comparison, enforced CNI fixtures and Restricted workload admission | Integrate tested TLS/WAF gateway, protect operator routes, eliminate alternate entry points; enforce complete application network graph and image provenance/signature admission |
| Database and workload controls | Scoped SQL identities/rotation, restricted application workloads and durable DB/telemetry stores verified | Regenerate these controls as state artifacts and re-run their checks with the complete identity/broker/gateway deployment |
| Residual-risk learning | Explicit assumed-compromise/canary design and honest effect-based evidence contract | Implement same-process authorized-channel misuse, denied outside-grant counterpart, settled downstream effects, independent evidence and two deterministic resets |
| Runtime evaluation | Technology and supplier evaluation contracts | Select/pin one open-source observation/enforcement engine; verify host/kernel hooks, contrast alerts with prevented effects, and measure overhead/false blocks |
| Learner interface and onboarding | Experiment console, account session page, Chrome checks and lightweight resource guards | Unified workflow from supported clean machine; phase selection/setup/reset/evidence/assessment; accurate active-control status; memory/startup budgets and recovery instructions |
| CCC and evidence | Proposed mappings, sanitized per-control results and external evidence boundaries | Verify versioned requirements, link each claimed control to a passing integrated result and limitations; retain evidence outside compromised workloads; no compliance certification claim |
| Release/reproduction | Repo gates pass for current work; generated-state publication invariant is documented | Fresh-clone/CI generation and full positive/negative trading campaign; independent contributor walkthrough; docs portal build/local and publication checks, secret/license review, pinned artifacts and approved publication |

These are integration and reproducibility gaps, not a small final documentation task.
Many local checks pass, but neither their count nor the number of completed subtasks
establishes acceptance of the combined hardened trading deployment.

## Release scope

The core security state must demonstrate normal trading under the integrated controls,
at least one bounded residual-authority scenario, recovery, trustworthy evidence and
one open-source runtime comparison. Do not advertise a fixture-only control as live
protection. Preserve a lightweight learning/development mode and a separately measured
full-C3 acceptance mode; never require two full clusters on the learner's machine.

The CVE/upstream-fix/OSERA branch stays on the roadmap. It needs its own pinned
reachable reproducer, VEX/provenance matching, fixed/backpatched comparison and
positive controls before it is advertised as runnable. A core release may explicitly
label this optional branch planned; publishing the *whole advertised CVE experience*
requires those gates as well. Do not silently remove this requested work.

Supplier-product evaluation depends on its supported-runtime/install/enforcement
contract and need not block the open-source state. Hosted workshops are a separate
deployment deliverable, not a prerequisite for publishing a reproducible local state.
CALM follows security acceptance and receives a separate state ID.

## Execution order

1. Finish unified local onboarding and freeze the core state's acceptance matrix.
2. Promote the canonical profile into a registered root state pack and generation path
   while marking unfinished exercises planned. Registration is not publication.
3. Complete user/trading authorization and live broker integration together.
4. Integrate gateway, full network segmentation and image trust; run normal trading and
   all negative checks against that same pinned deployment.
5. Add the bounded residual-authority exercise, one runtime engine, independent evidence
   and deterministic recovery; complete CCC mapping and resource/performance measurements.
6. Finish guided learning, independent clean-machine reproduction and CI/docs gates.
7. Prepare the generated snapshot/artifact release. Only then request approval for the
   concrete publication; no push, issue, PR or deployment is authorized by this audit.

Publication should follow TraderX's existing catalog/pipeline and single-snapshot
branch invariant. FINOS commits require DCO sign-off. This document is the release
checklist; `tasks.md` remains the implementation ledger and evidence links establish
what has actually passed.
