# Feature Pack 019: TraderX Security Lab

![linux/mac support](https://badgen.net/badge/linux%2Fmac/validation%20pending/yellow) ![windows support](https://badgen.net/badge/windows/not%20supported/red)

**Status: planned state; working experimental checkpoints, not an accepted integrated release.**

Parent: **012 / C3**. This is a first-class optional TraderX learning branch. It teaches which layer blocks an action, which layer detects it, and which effects remain possible after an application process is compromised.

The implementation currently lives in the [C3 experimental profile](../012-platform-convergence-c3/security-lab/README.md) and `scripts/security-lab`. Keep that single source during promotion; do not duplicate or silently relocate hash-pinned fixtures. The [release audit](../012-platform-convergence-c3/security-lab/state-readiness.md) distinguishes local proof from remaining integration.

Start with the [specification](spec.md), [learning contract](learning-contract.json), [plan](plan.md), [tasks](tasks.md), and [prototype quickstart](quickstart.md). CALM will be a separate successor, comparing manually implemented boundaries with model-derived controls against the same evidence contract.

The current integration work connects the [real Angular browser journey](system/browser-journey.md) to the authenticated services and builds the first [runnable Python role images](system/runtime-images.md). Their hosted evidence advances the [Phase 1/2 acceptance boundary](system/integrated-acceptance.md); it does not publish or activate the generated state.

See the [first-release completion assessment](system/completion-roadmap.md) for the remaining acceptance blocks, planning estimate and explicitly deferred follow-on work.

The [packaged-worker delivery checkpoint](evidence/2026-11-26-worker-image-delivery.json) adds 43 hosted TLS, recovery and rejection checks using the actual worker images. The next packaging gate is the position-service private configuration/TLS adapter.
