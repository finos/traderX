# Feature Pack 007: Observability with LGTM on Compose

![linux/mac support](https://badgen.net/badge/linux%2Fmac/supported/green?icon=linux) ![windows support](https://badgen.net/badge/windows/not%20supported/red?icon=windows)

Status: Implemented
Track: `nonfunctional`
Previous state: `006-messaging-nats-replacement`

This pack defines the convergence `C1` state after `006-messaging-nats-replacement`.

Primary intent:

- add a practical LGTM observability stack on top of the containerized baseline,
- keep business flows unchanged while improving runtime visibility,
- provide prebuilt Grafana dashboards for developer/operator learning,
- keep generation fully spec-first through state patch overlays.

Core artifacts:

- `spec.md`
- `requirements/functional-delta.md`
- `requirements/nonfunctional-delta.md`
- `research.md`
- `data-model.md`
- `quickstart.md`
- `contracts/contract-delta.md`
- `system/architecture.model.json`
- `system/runtime-topology.md`
- `generation/generation-hook.md`
- `tests/smoke/README.md`
