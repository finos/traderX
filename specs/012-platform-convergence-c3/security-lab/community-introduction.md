# Presenting the TraderX Security Lab to the community

Status: documentation/launch blueprint and draft copy, not a published announcement.
Use the assigned security-state ID only after catalog registration. The destination
is a first-class learning branch from C3; this is not a standalone unrelated product.
The actual release claims must follow state-readiness.md and pinned acceptance evidence.

## Two complementary portals

The TraderX docs portal explains the learning journey, prerequisites, controls,
architecture and results. The experiments portal executes bounded scenarios and
shows active configuration, authoritative outcomes, reset and downloadable evidence.
A reader should be able to understand an experiment without running it, and a runner
should always have a link back to its explanation. Do not embed an unauthenticated
live experiment iframe in public documentation. A hosted sandbox needs its own
identity, isolation, quota and exposure acceptance before it is linked as available.

## Documentation landing page

Lead with: **Which security layer stopped this action—and what can still happen?**

Suggested introduction:

> TraderX's Security Lab is a learning state built on C3. It lets you predict an
> outcome, run a controlled experiment, inspect the enforcing layer and resulting
> state, and reset the synthetic trading environment. Its purpose is to explain
> both effective controls and their limits—not to treat an alert or blocked HTTP
> request as proof that every downstream effect was prevented.

Use three clear entry routes: **Explore the learning map**, **Run locally**, and
**Try your first experiment**. Show the supported platform, required resources and
maturity near the entry points. Only add **Open hosted sandbox** once a reviewed
hosted environment exists. Every exercise must be labelled available, fixture-only,
planned or blocked as appropriate. Do not show planned scenarios as active buttons.

Render the learning progression as Mermaid from the canonical progression model,
using the docs portal's existing Mermaid support. Make each phase link to its guide
and evidence; include a textual/table equivalent for accessibility. Do not rasterize
the map into a screenshot or maintain an independent hand-edited copy. Keep links to
full architecture and trust-boundary diagrams for readers who want deeper detail.

## A curated visual walkthrough

Use three or four annotated screenshots in the main walkthrough, each answering a
specific learner question. Put additional screenshots in individual exercise guides.

| Visual | Learner question | Required caption/proof |
| --- | --- | --- |
| Experiment chooser | What can I try, and where should I start? | State/release, phase, available versus planned exercises, local resource mode |
| A permitted action beside a denial | Which boundary made the decision? | Scenario, active controls, positive counterpart, actual HTTP/broker/SQL outcome |
| Evidence/result view | Did anything change after the request? | Run ID, configuration pins, before/after state, attribution and limitation |
| Residual-authority example, once implemented | What remains possible despite the controls? | Explicit assumed-compromise label, bounded synthetic effect and control scope |

The logo-spacing screenshot and account-session browser captures demonstrate current
UI work, but they are not substitutes for a release walkthrough. Capture release
screenshots from the exact pinned state, at readable desktop and selected mobile
sizes. Include concise alt text and captions. Never expose credentials, cookies,
tokens, personal machine paths, unreviewed internal URLs or production data. Store
sanitized assets with source-state/scenario metadata so UI changes can invalidate
stale illustrations. Do not fabricate result dashboards for unimplemented scenarios.

A short video (roughly 3–5 minutes) should follow one complete story: predict → run
positive/negative pair → inspect effect/evidence → reset → explain one limitation.
Provide captions/transcript and the exact commands/release used. Video complements
reproducible instructions; it must not become the only explanation.

## Exercise page template

Each page should state the learning objective, prerequisite phase, threat assumption,
active controls and scope. Ask the learner to predict the result, show the exact
bounded action, then guide inspection of the decision and authoritative effect.
Include the expected positive control, reset, a downloadable sanitized example result,
and one assessment question about a counterexample outside the demonstrated scope.
Link back to the map, the relevant control contract and the next phase. Explain local
fixtures versus integrated trading checks directly beside the claims.

For the identity checkpoint, ask: "After local logout, which credential is invalid?"
The answer distinguishes the browser session from provider SSO and copied bearer
tokens. For the later database canary, ask why a legitimate SQL connection is not
sufficient evidence of legitimate business authorization.

## Community introduction sequence

1. Before release, recruit an independent contributor to follow the clean-machine
   guide and record friction. Resolve onboarding and resource failures before a demo.
2. Prepare a short release article, architecture/learning map, screenshots, captioned
   demo, known limitations and contribution guide. Check all claims against acceptance.
3. After release approval, introduce it through the existing TraderX/FINOS repository
   and community channels, with a community-call walkthrough if maintainers want one.
   No channel message, PR, issue, invitation or publication is authorized by this plan.
4. Invite concrete contributions: reproduce a scenario on a supported platform,
   improve a positive control, add a bounded exercise with effect-based evidence, or
   improve accessibility/documentation. Identify beginner and advanced tasks.
5. Introduce CALM later as the successor-state question: how much of the same verified
   control configuration can be derived from the architecture model? Keep equivalent
   tests so reduced effort and equivalent outcomes can be measured.

## Announcement draft — fill only with accepted release claims

**TraderX Security Lab: learn which controls work, and where their authority ends**

We are introducing a new learning state built on TraderX C3. The lab combines a
phased learning guide with repeatable security experiments against synthetic trading
data. Start with a working application, add verified controls, and inspect both the
security decision and the resulting system state.

The release walkthrough demonstrates [insert only accepted integrated scenarios].
Every exercise includes a permitted counterpart, reproducible configuration, reset
instructions and an explicit limitation. The learning map makes it clear what is
available and what remains planned.

Start here: [published state guide]. Run it: [supported setup instructions]. Inspect
the evidence: [sanitized pinned example]. Contribute: [maintainer-approved guide].

This is a practical learning/reference environment, not a compliance certification
or a claim that the application is immune to compromise. Future work includes
[only the actually deferred CVE/OSERA, runtime-product or CALM work].

## Publication acceptance

The new state's learning contract is the source for generated learning docs. Register
its sidebar/catalog/graph entries using the existing generators, then verify learning
parity and front matter. Add screenshot metadata/accessibility checks, render Mermaid
in the local docs preview, run the docs build and AFDocs/local checks, and check the
published URLs only after approved publication. The current environment has not yet
built or published this new state's portal pages; this file defines the work.
