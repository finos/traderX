# Feature Pack 014: FDC3 Intent Interoperability on C3

![linux/mac support](https://badgen.net/badge/linux%2Fmac/supported/green?icon=linux) ![windows support](https://badgen.net/badge/windows/not%20supported/red?icon=windows)

Status: Planned  
Track: `functional`  
Lineage role: `canonical`  
Previous state: `012-platform-convergence-c3`

This pack defines a functional interoperability layer on top of the C3 convergence baseline.

Primary intent:

- make TraderX an FDC3 2.2-capable application that can exchange ticker context with desktop ecosystem apps,
- support intent-driven ticket launch workflows (trade and order ticket prefilled from ticker context),
- preserve existing TraderX trade/order/position behavior when FDC3 is unavailable,
- provide deterministic tests that demonstrate FDC3 behavior against mocked and real demo-agent environments.

Core artifacts:

- `spec.md`
- `requirements/functional-delta.md`
- `requirements/nonfunctional-delta.md`
- `research.md`
- `data-model.md`
- `quickstart.md`
- `contracts/contract-delta.md`
- `system/architecture.model.json`
- `system/architecture.md`
- `system/runtime-topology.md`
- `generation/generation-hook.md`
- `tests/smoke/README.md`

Target runtime behavior:

- Standard FDC3 context exchange (`fdc3.instrument`) between TraderX and external apps.
- Standard intent handling (`ViewOrders`) and outbound intent raising (`ViewChart`, `ViewQuote`).
- Custom intent handling for prefilled ticket launch (`TraderX.CreateTradeTicket`, `TraderX.CreateOrderTicket`).
- Two-tab Sail demo profile with ticket-launch controls on tab `One` and news on tab `Two`.
- Documented workaround debt for current Sail callback reliability and non-CDM symbology normalization.
