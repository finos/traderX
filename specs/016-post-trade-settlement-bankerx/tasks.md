# Tasks: 016-post-trade-settlement-bankerx

- [x] T01601 Define functional deltas in `requirements/functional-delta.md`.
- [x] T01602 Define non-functional deltas in `requirements/nonfunctional-delta.md`.
- [x] T01603 Document research and constraints in `research.md`.
- [x] T01604 Define data-model impacts in `data-model.md`.
- [x] T01605 Author operator/developer run instructions in `quickstart.md`.
- [x] T01606 Define interoperability contract deltas in `contracts/contract-delta.md`.
- [x] T01607 Author architecture deltas in `system/architecture.md` (trilateral settlement topology).
- [x] T01608 Implement the `fdc3.paymentContext` builder (amount, currency, pair, rate, debtor, creditor, networkRouting, `uetr`) per FR-01603.
- [x] T01609 Implement FDC3 3.0 Desktop Agent capability detection with structured resolution logging (FR-01604).
- [x] T01610 Implement the `SETTLE (BANKERX)` action on confirmed Trade Blotter rows (FR-01601).
- [x] T01611 Dispatch `fdc3.raiseIntent("StartPayment", paymentContext)` from the blotter action (FR-01602).
- [x] T01612 Implement the graceful fallback toast + direct dispatch link when no Desktop Agent is available (FR-01605).
- [x] T01613 Implement inbound settlement-status handling: `pacs.002` (`Acsc`) marks blotter rows `SETTLED` (FR-01606).
- [x] T01614 Implement the BankerX DvP settlement adapter and ISO 20022 pacs.008/pacs.002 reference flow (commit `c80566f`).
- [ ] T01615 Add unit tests for payment-context building and agent detection.
- [ ] T01616 Add integration tests with a mocked DesktopAgent (`raiseIntent` round-trip to settlement confirmation).
- [ ] T01617 Add degraded-mode regression tests (FDC3 unavailable → baseline blotter behavior preserved).
- [ ] T01618 Run quality gates (validate-frontmatter, Spec Kit gates, spec coverage, docs build as available).
- [ ] T01619 Future remediation: extend `networkRouting` to carry per-leg rail receipts (XRPL/Solana/SynapticChain) once pacs.002 leg detail is standardized upstream.

## Dependency Notes

- T01608/T01609 are prerequisites for T01610-T01613.
- T01614 (BankerX reference flow) validates the payload contract consumed by T01608-T01613.
- T01615/T01616/T01617 should pass before considering the demo path complete (T01618).