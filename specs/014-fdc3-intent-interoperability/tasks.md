# Tasks: 014-fdc3-intent-interoperability

- [x] T01401 Define functional deltas in `requirements/functional-delta.md`.
- [x] T01402 Define non-functional deltas in `requirements/nonfunctional-delta.md`.
- [x] T01403 Document research and constraints in `research.md`.
- [x] T01404 Define data-model impacts in `data-model.md`.
- [x] T01405 Author operator/developer run instructions in `quickstart.md`.
- [x] T01406 Define interoperability contract deltas in `contracts/contract-delta.md`.
- [x] T01407 Author architecture/runtime topology deltas in `system/architecture.model.json` and `system/runtime-topology.md`.
- [ ] T01408 Implement Angular FDC3 bootstrap service and agent capability detection.
- [ ] T01409 Implement canonical ticker context mappers for trade/order/position entities.
- [ ] T01410 Implement outbound context publication from blotter row-selection interactions.
- [ ] T01411 Implement outbound intent actions (`ViewChart`, `ViewQuote`) from TraderX UI.
- [ ] T01412 Implement inbound context listener (`fdc3.instrument`) and ticker-scoped filtering behavior.
- [ ] T01413 Implement inbound intent listener for standard `ViewOrders`.
- [ ] T01414 Implement inbound intent listeners for `TraderX.CreateTradeTicket` and `TraderX.CreateOrderTicket`.
- [ ] T01415 Update generated runtime/app metadata with declared supported intents and contexts.
- [ ] T01416 Add unit tests for context mapping and intent/context listener behavior.
- [ ] T01417 Add integration tests using mocked DesktopAgent APIs (`getAgent`, `broadcast`, `raiseIntent`, listeners).
- [x] T01418 Add local Sail sidecar runtime assets (container definition, app-directory files, start/status/stop wrappers).
- [x] T01419 Add TraderX AppD entry for Sail with intent/context declarations and launch metadata.
- [x] T01420 Include reachable Sail demo apps (TraderX Intent Launcher + frameable TradingView/Pricer apps + FINOS conformance apps) in local directory profile and verify compatibility.
- [ ] T01421 Add E2E verification for TraderX to Sail demo flows.
- [x] T01422 Implement and harden `scripts/test-state-014-fdc3-intent-interoperability.sh`.
- [ ] T01423 Finalize generation hook summary/output and ensure render artifacts are deterministic.
- [ ] T01424 Run quality gates (`validate-frontmatter`, SpecKit gates, spec coverage, docs build as available).
- [ ] T01425 Publish generated snapshot branch and update downstream docs as needed.
- [x] T01426 Keep TraderX outbound payload canonical (`ticker` only) and isolate Sail compatibility patching to generated Sail bootstrap assets.
- [ ] T01427 Future remediation: replace Sail-side symbol patchwork mapper with CDM-native symbology resolution shared across apps/states.
- [ ] T01428 Future remediation: remove startup override patching once upstream Sail widgets consume canonical FDC3/CDM identifiers directly.
- [ ] T01429 Define and implement `traderx.account` context publishing/listening for main TraderX and Mini TraderX.
- [ ] T01430 Add `/mini-traderx` standalone Angular route using the existing live position blotter and pricing services.
- [ ] T01431 Publish Mini TraderX through the TraderX-owned App Directory source and seeded Sail demo workspace.
- [ ] T01432 Extend Sail smoke coverage to verify Mini TraderX receives real `fdc3.instrument` and `traderx.account` contexts.
- [x] T01433 Track upstream FDC3/Sail follow-up candidates without submitting upstream changes yet (`system/upstream-followups.md`).
- [ ] T01434 Add TraderX-owned FDC3 App Directory endpoint for core TraderX, Mini TraderX, and TraderX Intent Launcher records.
- [ ] T01435 Add Sail multi-App Directory source support for preconfigured demo startup, including environment-variable driven directory URL lists.
- [ ] T01436 Add Sail GUI support for adding/removing App Directory sources at runtime and showing source status.
- [ ] T01437 Decide whether to add an additional TraderX-owned demo app, with TraderX Streaming Price Widget as the preferred candidate if the demo needs another compact component.

## Dependency Notes

- T01408/T01409 are prerequisites for T01410-T01414.
- T01418-T01420 should complete before T01421.
- T01415 should be completed before T01421 so resolver menus expose TraderX handlers in Sail.
- T01416/T01417 and T01421 should pass before considering demo environment complete.
